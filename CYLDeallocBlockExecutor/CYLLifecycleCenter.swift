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
        return identifier
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

    /**
     * For tests: removes every observer and forgets the scroll state.
     */
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        entries = []
        scrollingOwners.removeAllObjects()
    }
}
