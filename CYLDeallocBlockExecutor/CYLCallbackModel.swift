//
//  CYLCallbackModel.swift
//  CYLDeallocBlockExecutor
//
//  Copyright © 2026 https://github.com/ChenYilong . All rights reserved.
//

import Foundation
import ObjectiveC

/**
 * The lock of the dealloc API, shared by the lifecycle API: it guards creating an object's callback model and handing out
 * its identifiers, so dealloc blocks and lifecycle blocks of one object share one identifier sequence.
 */
let cylDeallocCallbackLock = NSRecursiveLock()

private var cylCallbackModelKey: UInt8 = 0
private var cylGlobalIdentifierKey: UInt8 = 0

/**
 * A lifecycle block with its owner type erased; the typed wrapper casts the owner back.
 */
typealias CYLLifecycleErasedCallback = (_ owner: AnyObject, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void

/**
 * The blocks of one object: its dealloc blocks (run when the model is released with its owner) and its lifecycle blocks.
 * Every mutation and every read happens under `lock`; blocks always run outside it, so a block can add or cancel blocks.
 */
final class CYLCallbackModel {

    private struct LifecycleEntry {
        let event: CYLLifecycleEvent?
        let custom: String?
        let timing: CYLLifecycleTiming
        let invokeOnce: Bool
        let key: String?
        var fired: Bool
        let callback: CYLLifecycleErasedCallback
    }

    private struct DispatchPoint: Hashable {
        let event: CYLLifecycleEvent
        let timing: CYLLifecycleTiming
    }

    private let lock = NSLock()
    private let owner: Unmanaged<AnyObject>
    private var deallocCallbacks: [UInt: CYLDeallocCallback] = [:]
    private var deallocKeys: [String: UInt] = [:]
    private var lifecycleEntries: [UInt: LifecycleEntry] = [:]
    private var lifecycleKeys: [String: UInt] = [:]
    private var manualPoints: Set<DispatchPoint> = []
    private var performingCounts: [CYLLifecycleEvent: Int] = [:]
    private var forwards: [(target: Weak, events: Set<CYLLifecycleEvent>?)] = []

    private final class Weak {
        weak var object: NSObject?
        init(_ object: NSObject) { self.object = object }
    }

    init(owner: AnyObject) {
        self.owner = Unmanaged.passUnretained(owner)
    }

    deinit {
        // Run in the order the callbacks were added.
        let info = CYLLifecycleInfo.dealloc
        CYLLifecycleLog.log("teardown \(CYLLifecycleLog.describe(owner.takeUnretainedValue())): \(deallocCallbacks.count) block(s)")
        for key in deallocCallbacks.keys.sorted() {
            deallocCallbacks[key]?(owner, key, info)
        }
        CYLLifecycleCenter.dispatchDealloc(owner: owner.takeUnretainedValue())
    }

    // MARK: - Dealloc

    /**
     * Adds a dealloc block; with a key, the block added before under the same key is removed in the same step.
     */
    @discardableResult
    func addDeallocCallback(_ callback: @escaping CYLDeallocCallback, identifier: UInt, key: String? = nil) -> UInt {
        guard identifier > 0 else { return cylDeallocCallbackIllegalIdentifier }
        lock.lock(); defer { lock.unlock() }
        if let key {
            if let previous = deallocKeys[key] {
                deallocCallbacks.removeValue(forKey: previous)
            }
            deallocKeys[key] = identifier
        }
        deallocCallbacks[identifier] = callback
        return identifier
    }

    /**
     * Returns true when a block with this identifier was removed, false when there is none (never added, already
     * cancelled, or the illegal identifier 0).
     */
    func removeDeallocCallback(identifier: UInt) -> Bool {
        guard identifier != cylDeallocCallbackIllegalIdentifier else { return false }
        lock.lock(); defer { lock.unlock() }
        let removed = deallocCallbacks.removeValue(forKey: identifier) != nil
        deallocKeys = deallocKeys.filter { $0.value != identifier }
        return removed
    }

    /**
     * Removes the dealloc blocks added without a key; keyed blocks belong to whoever holds the key.
     */
    func removeAllDeallocCallbacks() {
        lock.lock(); defer { lock.unlock() }
        let keyed = Set(deallocKeys.values)
        deallocCallbacks = deallocCallbacks.filter { keyed.contains($0.key) }
    }

    // MARK: - Lifecycle blocks

    /**
     * Adds a lifecycle block; with a key, the block added before under the same key is removed in the same step (the new
     * block starts unfired, so replacing an invoke-once block also re-arms it).
     */
    func addLifecycleCallback(_ callback: @escaping CYLLifecycleErasedCallback, identifier: UInt, event: CYLLifecycleEvent,
                              timing: CYLLifecycleTiming, invokeOnce: Bool, key: String?) {
        lock.lock(); defer { lock.unlock() }
        if let key {
            if let previous = lifecycleKeys[key] {
                lifecycleEntries.removeValue(forKey: previous)
            }
            lifecycleKeys[key] = identifier
        }
        lifecycleEntries[identifier] = LifecycleEntry(event: event, custom: nil, timing: timing, invokeOnce: invokeOnce, key: key, fired: false,
                                                      callback: callback)
    }

    /**
     * Adds a custom event block; keys replace within the lifecycle blocks, as for the built-in events.
     */
    func addCustomCallback(_ callback: @escaping CYLLifecycleErasedCallback, identifier: UInt, custom: String, invokeOnce: Bool,
                           key: String?) {
        lock.lock(); defer { lock.unlock() }
        if let key {
            if let previous = lifecycleKeys[key] {
                lifecycleEntries.removeValue(forKey: previous)
            }
            lifecycleKeys[key] = identifier
        }
        lifecycleEntries[identifier] = LifecycleEntry(event: nil, custom: custom, timing: .afterSuper, invokeOnce: invokeOnce, key: key,
                                                      fired: false, callback: callback)
    }

    /**
     * The custom event blocks to run now for `name`, in the order they were added; invoke-once blocks are marked fired here.
     */
    func takeCustomCallbacks(name: String) -> [(UInt, CYLLifecycleErasedCallback)] {
        lock.lock(); defer { lock.unlock() }
        var result: [(UInt, CYLLifecycleErasedCallback)] = []
        for identifier in lifecycleEntries.keys.sorted() {
            guard let entry = lifecycleEntries[identifier], entry.custom == name, !(entry.invokeOnce && entry.fired) else { continue }
            if entry.invokeOnce {
                lifecycleEntries[identifier]?.fired = true
            }
            result.append((identifier, entry.callback))
        }
        return result
    }

    // MARK: - Forwarding

    /// Returns true when the forward is new or changed, so a repeated identical call (every layout pass) costs nothing.
    @discardableResult
    func setForward(to target: NSObject, events: Set<CYLLifecycleEvent>?) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let existing = forwards.first(where: { $0.target.object === target }), existing.events == events { return false }
        forwards.removeAll { $0.target.object == nil || $0.target.object === target }
        forwards.append((Weak(target), events))
        return true
    }

    /**
     * The live targets that receive `event` (nil: a posted custom event, which every forward receives).
     */
    func forwardTargets(for event: CYLLifecycleEvent?) -> [NSObject] {
        lock.lock(); defer { lock.unlock() }
        forwards.removeAll { $0.target.object == nil }
        return forwards.compactMap { entry in
            guard let target = entry.target.object else { return nil }
            if let event, let events = entry.events, !events.contains(event) { return nil }
            return target
        }
    }

    /**
     * Whether a block waits for `event` (at any timing), for the lazy sources.
     */
    func hasLifecycleBlocks(for event: CYLLifecycleEvent) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return lifecycleEntries.values.contains { $0.event == event } || forwards.contains { $0.events?.contains(event) ?? true }
    }

    func removeLifecycleCallback(identifier: UInt) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let entry = lifecycleEntries.removeValue(forKey: identifier) else { return false }
        if let key = entry.key, lifecycleKeys[key] == identifier {
            lifecycleKeys.removeValue(forKey: key)
        }
        return true
    }

    /**
     * Removes the blocks of `event` added without a key; keyed blocks belong to whoever holds the key.
     */
    func removeAllLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming?) {
        lock.lock(); defer { lock.unlock() }
        lifecycleEntries = lifecycleEntries.filter { $0.value.key != nil || !Self.matches($0.value, event, timing) }
    }

    /**
     * Re-arms the invoke-once blocks of `event` added without a key; keyed blocks are re-armed by their key.
     */
    func rearmLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming?) {
        lock.lock(); defer { lock.unlock() }
        for (identifier, entry) in lifecycleEntries where entry.key == nil && entry.invokeOnce && Self.matches(entry, event, timing) {
            lifecycleEntries[identifier]?.fired = false
        }
    }

    func lifecycleIdentifier(key: String) -> UInt? {
        lock.lock(); defer { lock.unlock() }
        return lifecycleKeys[key]
    }

    func deallocIdentifier(key: String) -> UInt? {
        lock.lock(); defer { lock.unlock() }
        return deallocKeys[key]
    }

    func rearmLifecycleCallback(identifier: UInt) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard lifecycleEntries[identifier] != nil else { return false }
        lifecycleEntries[identifier]?.fired = false
        return true
    }

    func containsLifecycleCallback(identifier: UInt) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return lifecycleEntries[identifier] != nil
    }

    /**
     * The blocks to run now for `event` at `timing`, in the order they were added. Invoke-once blocks are marked fired
     * here, under the lock, so two dispatches never run one of them twice.
     */
    func takeLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming) -> [(UInt, CYLLifecycleErasedCallback)] {
        lock.lock(); defer { lock.unlock() }
        var result: [(UInt, CYLLifecycleErasedCallback)] = []
        for identifier in lifecycleEntries.keys.sorted() {
            guard let entry = lifecycleEntries[identifier], entry.event == event, entry.timing == timing,
                  !(entry.invokeOnce && entry.fired) else { continue }
            if entry.invokeOnce {
                lifecycleEntries[identifier]?.fired = true
            }
            result.append((identifier, entry.callback))
        }
        return result
    }

    // MARK: - Dispatch state

    func setManualDispatch(_ manual: Bool, events: Set<CYLLifecycleEvent>, timings: Set<CYLLifecycleTiming>) {
        let points = events.flatMap { event in timings.map { DispatchPoint(event: event, timing: $0) } }
        lock.lock(); defer { lock.unlock() }
        if manual {
            manualPoints.formUnion(points)
        } else {
            manualPoints.subtract(points)
        }
    }

    func isManualDispatch(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return manualPoints.contains(DispatchPoint(event: event, timing: timing))
    }

    func beginPerforming(_ event: CYLLifecycleEvent) {
        lock.lock(); defer { lock.unlock() }
        performingCounts[event, default: 0] += 1
    }

    func endPerforming(_ event: CYLLifecycleEvent) {
        lock.lock(); defer { lock.unlock() }
        let count = (performingCounts[event] ?? 1) - 1
        performingCounts[event] = count > 0 ? count : nil
    }

    func isPerforming(_ event: CYLLifecycleEvent) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return performingCounts[event] != nil
    }

    /**
     * Whether the automatic hook dispatches `event` at `timing`: some block waits for it and the owner did not declare that
     * point manual; `.end` also waits while the owner runs `cylPerformLifecycle` for the event.
     */
    func dispatchesAutomatically(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !manualPoints.contains(DispatchPoint(event: event, timing: timing)) else { return false }
        // While an override runs cylPerformLifecycle, it fires .end itself at its outermost level.
        guard timing != .end || performingCounts[event] == nil else { return false }
        return lifecycleEntries.values.contains { $0.event == event && $0.timing == timing }
    }

    private static func matches(_ entry: LifecycleEntry, _ event: CYLLifecycleEvent, _ timing: CYLLifecycleTiming?) -> Bool {
        entry.event == event && (timing == nil || entry.timing == timing)
    }
}

// MARK: - Storage on the owner

extension NSObject {

    /**
     * The next identifier of this object and its model, created when missing; both under the dealloc lock, as in 1.3.0.
     */
    func cylMakeCallbackIdentifierAndModel() -> (UInt, CYLCallbackModel) {
        cylDeallocCallbackLock.lock(); defer { cylDeallocCallbackLock.unlock() }
        let previous = (objc_getAssociatedObject(self, &cylGlobalIdentifierKey) as? NSNumber)?.uintValue ?? 0
        let identifier = previous + 1
        objc_setAssociatedObject(self, &cylGlobalIdentifierKey, NSNumber(value: identifier), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return (identifier, cylCallbackModelLocked(create: true)!)
    }

    /**
     * The model of this object; created when `create` is true and it is missing.
     */
    func cylCallbackModel(create: Bool) -> CYLCallbackModel? {
        if let model = objc_getAssociatedObject(self, &cylCallbackModelKey) as? CYLCallbackModel {
            return model
        }
        guard create else { return nil }
        cylDeallocCallbackLock.lock(); defer { cylDeallocCallbackLock.unlock() }
        return cylCallbackModelLocked(create: true)
    }

    private func cylCallbackModelLocked(create: Bool) -> CYLCallbackModel? {
        if let model = objc_getAssociatedObject(self, &cylCallbackModelKey) as? CYLCallbackModel {
            return model
        }
        guard create else { return nil }
        let model = CYLCallbackModel(owner: self)
        objc_setAssociatedObject(self, &cylCallbackModelKey, model, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return model
    }
}
