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

/// Dealloc block aligned with the lifecycle blocks: owner, identifier and info (`info.isDealloc` is true,
/// `info.timing` is `.end`). The owner is unretained for the same reason as in `CYLDeallocSelfCallback`.
public typealias CYLDeallocCallback = (_ owner: Unmanaged<AnyObject>, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void

/// The identifier no callback ever gets (`0`).
public let cylDeallocCallbackIllegalIdentifier: UInt = 0

/// Illegal identifier (1.3.0 name).
@available(*, deprecated, renamed: "cylDeallocCallbackIllegalIdentifier")
public let CYLDeallocCallbackIllegalIdentifier: UInt = cylDeallocCallbackIllegalIdentifier

private var executorsKey: UInt8 = 0

// MARK: - NSObject extension

extension NSObject {

    /// Add dealloc callback to object.
    ///
    /// - Returns: The task identifier.
    @discardableResult
    public func cylWillDealloc(selfCallback: @escaping CYLDeallocSelfCallback) -> UInt {
        cylWillDealloc(callback: { owner, identifier, _ in selfCallback(owner, identifier) })
    }

    /// Add a dealloc callback with the same parameters as the lifecycle callbacks (owner, identifier, info).
    /// Shares the identifier sequence, the lock and the cancel API of `cylWillDealloc(selfCallback:)`.
    ///
    /// - Returns: The task identifier.
    @discardableResult
    public func cylWillDealloc(callback: @escaping CYLDeallocCallback) -> UInt {
        let (identifier, model) = cylMakeCallbackIdentifierAndModel()
        return model.addDeallocCallback(callback, identifier: identifier)
    }

    /// Add a dealloc callback that replaces the one added before under the same key, so a setter that runs many times
    /// (a theme property, an observer added when a value arrives) keeps exactly one block.
    ///
    /// - Returns: The task identifier.
    @discardableResult
    public func cylWillDealloc(key: String, callback: @escaping CYLDeallocCallback) -> UInt {
        let (identifier, model) = cylMakeCallbackIdentifierAndModel()
        return model.addDeallocCallback(callback, identifier: identifier, key: key)
    }

    /// Remove callback by identifier.
    ///
    /// - Returns: Remove success or not.
    @discardableResult
    public func cylCancelDeallocCallback(identifier: UInt) -> Bool {
        guard let model = cylCallbackModel(create: false) else { return false }
        return model.removeDeallocCallback(identifier: identifier)
    }

    /// Remove the dealloc callback added under `key`.
    ///
    /// - Returns: Whether a callback had this key.
    @discardableResult
    public func cylCancelDeallocCallback(key: String) -> Bool {
        guard let model = cylCallbackModel(create: false), let identifier = model.deallocIdentifier(key: key) else { return false }
        return model.removeDeallocCallback(identifier: identifier)
    }

    /// Remove all dealloc callbacks added without a key (every 1.3.0 callback); keyed callbacks belong to whoever holds
    /// the key (`cylCancelDeallocCallback(key:)`).
    public func cylCancelAllDeallocCallbacks() {
        cylCallbackModel(create: false)?.removeAllDeallocCallbacks()
    }

    // MARK: 1.3.0 names

    /// 1.3.0 name of `cylWillDealloc(selfCallback:)`.
    @available(*, deprecated, renamed: "cylWillDealloc(selfCallback:)")
    @discardableResult
    public func cyl_willDealloc(selfCallback: @escaping CYLDeallocSelfCallback) -> UInt {
        cylWillDealloc(selfCallback: selfCallback)
    }

    /// 1.3.0 name of `cylCancelDeallocCallback(identifier:)`.
    @available(*, deprecated, renamed: "cylCancelDeallocCallback(identifier:)")
    @discardableResult
    public func cyl_cancelDeallocCallback(identifier: UInt) -> Bool {
        cylCancelDeallocCallback(identifier: identifier)
    }

    /// 1.3.0 name of `cylCancelAllDeallocCallbacks()`.
    @available(*, deprecated, renamed: "cylCancelAllDeallocCallbacks()")
    public func cyl_cancelAllDeallocCallbacks() {
        cylCancelAllDeallocCallbacks()
    }

    @available(*, deprecated, message: "Deprecated in 1.2.0. Use `cylWillDealloc(selfCallback:)` instead.")
    public func cyl_executeAtDealloc(_ block: @escaping CYLDeallocExecutorBlock) {
        let executor = CYLDeallocExecutor(block: block)
        cylDeallocCallbackLock.lock(); defer { cylDeallocCallbackLock.unlock() }
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
