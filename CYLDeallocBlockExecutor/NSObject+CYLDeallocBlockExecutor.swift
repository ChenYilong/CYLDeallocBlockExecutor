//
//  NSObject+CYLDeallocBlockExecutor.swift
//  v1.2.0
//  Created by 微博@iOS程序犭袁 ( http://weibo.com/luohanchenyilong/ ) on 15/12/27.
//  Copyright © 2015年 https://github.com/ChenYilong . All rights reserved.
//

import Foundation
import ObjectiveC

/// Dealloc task block definition.
///
/// - Parameters:
///   - owner: the object being deallocated (unretained — the original `__unsafe_unretained id`).
///            Do not store it or let it escape the callback.
///   - identifier: task identifier
public typealias CYLDeallocSelfCallback = (_ owner: Unmanaged<AnyObject>, _ identifier: UInt) -> Void

/// Illegal identifier.
public let CYLDeallocCallbackIllegalIdentifier: UInt = 0

// MARK: - Callback model

private final class CYLDeallocCallbackModel {

    private let lock = NSLock()
    private var callbacks: [UInt: CYLDeallocSelfCallback] = [:]
    private let owner: Unmanaged<AnyObject>

    init(owner: AnyObject) {
        self.owner = Unmanaged.passUnretained(owner)
    }

    @discardableResult
    func addSelfCallback(_ callback: @escaping CYLDeallocSelfCallback, identifier: UInt) -> UInt {
        guard identifier > 0 else { return CYLDeallocCallbackIllegalIdentifier }
        lock.lock(); defer { lock.unlock() }
        callbacks[identifier] = callback
        return identifier
    }

    func removeCallback(identifier: UInt) -> Bool {
        guard identifier != CYLDeallocCallbackIllegalIdentifier else { return false }
        lock.lock(); defer { lock.unlock() }
        callbacks.removeValue(forKey: identifier)
        return true
    }

    func removeAllCallbacks() {
        lock.lock(); defer { lock.unlock() }
        callbacks.removeAll()
    }

    deinit {
        // Run in the order the callbacks were added.
        for key in callbacks.keys.sorted() {
            callbacks[key]?(owner, key)
        }
    }
}

// MARK: - Associated-object keys / shared lock

private var modelKey: UInt8 = 0
private var executorsKey: UInt8 = 0
private var globalIdentifierKey: UInt8 = 0
private let deallocCallbackLock = NSRecursiveLock()

// MARK: - NSObject extension

extension NSObject {

    private var cyl_globalIdentifier: UInt {
        get { (objc_getAssociatedObject(self, &globalIdentifierKey) as? NSNumber)?.uintValue ?? 0 }
        set { objc_setAssociatedObject(self, &globalIdentifierKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Add dealloc callback to object.
    ///
    /// - Returns: The task identifier.
    @discardableResult
    public func cyl_willDealloc(selfCallback: @escaping CYLDeallocSelfCallback) -> UInt {
        let model: CYLDeallocCallbackModel
        deallocCallbackLock.lock()
        let identifier = cyl_globalIdentifier + 1
        cyl_globalIdentifier = identifier
        if let existing = objc_getAssociatedObject(self, &modelKey) as? CYLDeallocCallbackModel {
            model = existing
        } else {
            model = CYLDeallocCallbackModel(owner: self)
            objc_setAssociatedObject(self, &modelKey, model, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        deallocCallbackLock.unlock()
        return model.addSelfCallback(selfCallback, identifier: identifier)
    }

    /// Remove callback by identifier.
    ///
    /// - Returns: Remove success or not.
    @discardableResult
    public func cyl_cancelDeallocCallback(identifier: UInt) -> Bool {
        guard let model = objc_getAssociatedObject(self, &modelKey) as? CYLDeallocCallbackModel else { return false }
        return model.removeCallback(identifier: identifier)
    }

    /// Remove all dealloc callbacks.
    public func cyl_cancelAllDeallocCallbacks() {
        (objc_getAssociatedObject(self, &modelKey) as? CYLDeallocCallbackModel)?.removeAllCallbacks()
    }

    @available(*, deprecated, message: "Deprecated in 1.2.0. Use `cyl_willDealloc(selfCallback:)` instead.")
    public func cyl_executeAtDealloc(_ block: @escaping CYLDeallocExecutorBlock) {
        let executor = CYLDeallocExecutor(block: block)
        deallocCallbackLock.lock(); defer { deallocCallbackLock.unlock() }
        let executors: NSMutableArray
        if let existing = objc_getAssociatedObject(self, &executorsKey) as? NSMutableArray {
            executors = existing
        } else {
            executors = NSMutableArray()
            objc_setAssociatedObject(self, &executorsKey, executors, .OBJC_ASSOCIATION_RETAIN)
        }
        executors.add(executor)
    }
}
