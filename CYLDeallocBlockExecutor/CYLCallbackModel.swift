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
        let event: CYLLifecycleEvent
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

    init(owner: AnyObject) {
        self.owner = Unmanaged.passUnretained(owner)
    }

    deinit {
        // Run in the order the callbacks were added.
        let info = CYLLifecycleInfo.dealloc
        for key in deallocCallbacks.keys.sorted() {
            deallocCallbacks[key]?(owner, key, info)
        }
    }

    // MARK: - Dealloc

    /**
     * Adds a dealloc block; with a key, the block added before under the same key is removed in the same step.
     */
    @discardableResult
    func addDeallocCallback(_ callback: @escaping CYLDeallocCallback, identifier: UInt, key: String? = nil) -> UInt {
        guard identifier > 0 else { return CYLDeallocCallbackIllegalIdentifier }
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
     * Returns true for every legal identifier, as the 1.3.0 API did.
     */
    func removeDeallocCallback(identifier: UInt) -> Bool {
        guard identifier != CYLDeallocCallbackIllegalIdentifier else { return false }
        lock.lock(); defer { lock.unlock() }
        deallocCallbacks.removeValue(forKey: identifier)
        deallocKeys = deallocKeys.filter { $0.value != identifier }
        return true
    }

    func removeAllDeallocCallbacks() {
        lock.lock(); defer { lock.unlock() }
        deallocCallbacks.removeAll()
        deallocKeys.removeAll()
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
        lifecycleEntries[identifier] = LifecycleEntry(event: event, timing: timing, invokeOnce: invokeOnce, key: key, fired: false,
                                                      callback: callback)
    }

    func removeLifecycleCallback(identifier: UInt) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let entry = lifecycleEntries.removeValue(forKey: identifier) else { return false }
        if let key = entry.key, lifecycleKeys[key] == identifier {
            lifecycleKeys.removeValue(forKey: key)
        }
        return true
    }

    func removeAllLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming?) {
        lock.lock(); defer { lock.unlock() }
        lifecycleEntries = lifecycleEntries.filter { !Self.matches($0.value, event, timing) }
        lifecycleKeys = lifecycleKeys.filter { lifecycleEntries[$0.value] != nil }
    }

    func rearmLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming?) {
        lock.lock(); defer { lock.unlock() }
        for (identifier, entry) in lifecycleEntries where entry.invokeOnce && Self.matches(entry, event, timing) {
            lifecycleEntries[identifier]?.fired = false
        }
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
     * point manual; `.end` also waits while the owner runs `cyl_performLifecycle` for the event.
     */
    func dispatchesAutomatically(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !manualPoints.contains(DispatchPoint(event: event, timing: timing)) else { return false }
        // While an override runs cyl_performLifecycle, it fires .end itself at its outermost level.
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
    func cyl_makeCallbackIdentifierAndModel() -> (UInt, CYLCallbackModel) {
        cylDeallocCallbackLock.lock(); defer { cylDeallocCallbackLock.unlock() }
        let previous = (objc_getAssociatedObject(self, &cylGlobalIdentifierKey) as? NSNumber)?.uintValue ?? 0
        let identifier = previous + 1
        objc_setAssociatedObject(self, &cylGlobalIdentifierKey, NSNumber(value: identifier), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return (identifier, cyl_callbackModelLocked(create: true)!)
    }

    /**
     * The model of this object; created when `create` is true and it is missing.
     */
    func cyl_callbackModel(create: Bool) -> CYLCallbackModel? {
        if let model = objc_getAssociatedObject(self, &cylCallbackModelKey) as? CYLCallbackModel {
            return model
        }
        guard create else { return nil }
        cylDeallocCallbackLock.lock(); defer { cylDeallocCallbackLock.unlock() }
        return cyl_callbackModelLocked(create: true)
    }

    private func cyl_callbackModelLocked(create: Bool) -> CYLCallbackModel? {
        if let model = objc_getAssociatedObject(self, &cylCallbackModelKey) as? CYLCallbackModel {
            return model
        }
        guard create else { return nil }
        let model = CYLCallbackModel(owner: self)
        objc_setAssociatedObject(self, &cylCallbackModelKey, model, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return model
    }
}
