//
//  CYLLifecycleCenter.swift
//  CYLDeallocBlockExecutor
//
//  Copyright © 2026 https://github.com/ChenYilong . All rights reserved.
//

import UIKit

/**
 * Global observers (design v5): one block that observes an event on every object, for behavior that must not know its owners,
 * such as "pause every animation while the user scrolls". Per-owner blocks run first, then the global ones, each group in
 * identifier order. Global observers never receive dealloc: the owner is going away. A key replaces the observer added
 * before under it. Main thread only for the sources; the storage itself is locked.
 */
public enum CYLLifecycleCenter {

    private struct Entry {
        let identifier: UInt
        let event: CYLLifecycleEvent?
        let custom: String?
        let timing: CYLLifecycleTiming
        let ownerType: AnyClass?
        let key: String?
        let callback: (_ owner: AnyObject, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void
    }

    private static let lock = NSLock()
    private static var entries: [Entry] = []
    private static var nextIdentifier: UInt = 1
    private static let scrollingOwners = NSHashTable<AnyObject>.weakObjects()

    /**
     * Whether any observer waits for a window, screen or scroll event: the view hooks read it for every view move, so it is a
     * stored flag updated when observers change, not a search.
     */
    private(set) static var observesViewEvents = false

    private static func refreshFlags() {
        let viewEvents: Set<CYLLifecycleEvent> = [.willMoveToWindow, .didMoveToWindow, .didEnterScreen, .didLeaveScreen,
                                                  .scrollWillBeginDragging, .scrollDidEndDragging, .scrollDidEndScrolling]
        observesViewEvents = entries.contains { entry in entry.event.map { viewEvents.contains($0) } ?? false }
    }

    /**
     * True while any observed scroll view is dragging or decelerating.
     */
    public static var isUserScrolling: Bool {
        lock.lock(); defer { lock.unlock() }
        return scrollingOwners.count > 0
    }

    /**
     * Observes `event` on every object (or only on instances of `ownerType`), at `timing` (the 15 view controller events have all
     * three timings; the derived events only `.afterSuper`).
     *
     * - Returns: The identifier, for `cancelCallback(identifier:)`.
     */
    @discardableResult
    public static func addCallback(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming = .afterSuper, ownerType: AnyClass? = nil,
                                   key: String? = nil,
                                   callback: @escaping (_ owner: AnyObject, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void) -> UInt {
        let identifier = add(Entry(identifier: 0, event: event, custom: nil, timing: timing, ownerType: ownerType, key: key, callback: callback))
        if event.isViewControllerEvent {
            CYLLifecycleHooks.installIfNeeded()
        }
        CYLLifecycleSources.globalEventAdded(event)
        return identifier
    }

    /**
     * Observes the custom event `name` on every object (or only on instances of `ownerType`).
     */
    @discardableResult
    public static func addCallback(forCustomEvent name: String, ownerType: AnyClass? = nil, key: String? = nil,
                                   callback: @escaping (_ owner: AnyObject, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void) -> UInt {
        add(Entry(identifier: 0, event: nil, custom: name, timing: .afterSuper, ownerType: ownerType, key: key, callback: callback))
    }

    private static func add(_ prototype: Entry) -> UInt {
        lock.lock(); defer { lock.unlock() }
        if let key = prototype.key {
            entries.removeAll { $0.key == key }
        }
        let identifier = nextIdentifier
        nextIdentifier += 1
        entries.append(Entry(identifier: identifier, event: prototype.event, custom: prototype.custom, timing: prototype.timing,
                             ownerType: prototype.ownerType, key: prototype.key, callback: prototype.callback))
        refreshFlags()
        return identifier
    }

    /**
     * The ready-made version of "pause every animation while the user scrolls, resume afterwards": `pause` runs when any observed
     * scroll source starts to be dragged, `resume` when it stopped for good. Returns a function that removes both observers; they use
     * the keys `<key>.pause` and `<key>.resume` (default key `cyl.scroll`), so calling it again replaces the earlier pair.
     */
    @discardableResult
    public static func whileUserScrolls(key: String = "cyl.scroll", pause: @escaping () -> Void, resume: @escaping () -> Void) -> () -> Void {
        addCallback(for: .scrollWillBeginDragging, key: "\(key).pause") { _, _, _ in pause() }
        addCallback(for: .scrollDidEndScrolling, key: "\(key).resume") { _, _, _ in resume() }
        return {
            cancelCallback(key: "\(key).pause")
            cancelCallback(key: "\(key).resume")
        }
    }

    /**
     * Cancels one observer.
     *
     * - Returns: Whether an observer had this identifier.
     */
    @discardableResult
    public static func cancelCallback(identifier: UInt) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let before = entries.count
        entries.removeAll { $0.identifier == identifier }
        refreshFlags()
        return entries.count < before
    }

    /**
     * Cancels the observer added under `key`.
     */
    @discardableResult
    public static func cancelCallback(key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let before = entries.count
        entries.removeAll { $0.key == key }
        refreshFlags()
        return entries.count < before
    }

    /**
     * Whether a global observer waits for `event` (at `timing`, when given); the hooks use it to skip owners without blocks.
     */
    static func hasObservers(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return entries.contains { $0.event == event && (timing == nil || $0.timing == timing) }
    }

    /**
     * Called after the owner's own blocks ran. Tracks `isUserScrolling` and runs the matching observers outside the lock.
     */
    static func dispatch(owner: AnyObject, event: CYLLifecycleEvent?, custom: String?, timing: CYLLifecycleTiming, info: CYLLifecycleInfo) {
        lock.lock()
        if event == .scrollWillBeginDragging {
            scrollingOwners.add(owner)
        } else if event == .scrollDidEndScrolling {
            scrollingOwners.remove(owner)
        }
        let matching = entries.filter { entry in
            guard entry.event == event, entry.custom == custom else { return false }
            return custom != nil || entry.timing == timing
        }
        lock.unlock()
        for entry in matching.sorted(by: { $0.identifier < $1.identifier }) {
            if let ownerType = entry.ownerType, !((owner as? NSObject)?.isKind(of: ownerType) ?? false) { continue }
            var info = info
            info.event = event
            info.timing = timing
            info.customEvent = custom
            entry.callback(owner, entry.identifier, info)
        }
    }

    private struct DeallocObserver {
        let identifier: UInt
        let key: String?
        let callback: (_ description: String, _ info: CYLLifecycleInfo) -> Void
    }

    private static var deallocObservers: [DeallocObserver] = []

    /**
     * Observes the teardown of every object that has blocks, to know when any control (or any object) goes away. The callback gets
     * a description (class name and address), never the owner: it is being destroyed. For logging and bookkeeping, not cleanup.
     */
    @discardableResult
    public static func addDeallocObserver(key: String? = nil,
                                          callback: @escaping (_ description: String, _ info: CYLLifecycleInfo) -> Void) -> UInt {
        lock.lock(); defer { lock.unlock() }
        if let key {
            deallocObservers.removeAll { $0.key == key }
        }
        let identifier = nextIdentifier
        nextIdentifier += 1
        deallocObservers.append(DeallocObserver(identifier: identifier, key: key, callback: callback))
        return identifier
    }

    @discardableResult
    public static func cancelDeallocObserver(identifier: UInt) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let before = deallocObservers.count
        deallocObservers.removeAll { $0.identifier == identifier }
        return deallocObservers.count < before
    }

    /**
     * Called by an object's model while the object is being destroyed (`owner` is only described, never handed out).
     */
    static func dispatchDealloc(owner: AnyObject) {
        let description = CYLLifecycleLog.describe(owner)
        CYLLifecycleLog.log("dealloc \(description)")
        lock.lock()
        let observers = deallocObservers
        lock.unlock()
        for observer in observers {
            observer.callback(description, CYLLifecycleInfo.dealloc)
        }
    }

    /**
     * For tests: removes every observer and forgets the scroll state.
     */
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        entries = []
        deallocObservers = []
        scrollingOwners.removeAllObjects()
        refreshFlags()
    }
}
