//
//  CYLLifecycle.swift
//  CYLDeallocBlockExecutor
//
//  Copyright © 2026 https://github.com/ChenYilong . All rights reserved.
//

import UIKit
import ObjectiveC

/**
 * The UIViewController lifecycle events a block can wait for. Dealloc has its own API (`cylWillDealloc`).
 */
public enum CYLLifecycleEvent: Int, CaseIterable {
    case viewDidLoad
    case viewWillAppear
    /**
     * iOS 17+ (back-deployed to iOS 13 by UIKit when built with Xcode 15 or later); never fires where UIKit lacks it.
     */
    case viewIsAppearing
    case viewDidAppear
    case viewWillLayoutSubviews
    case viewDidLayoutSubviews
    case viewWillDisappear
    case viewDidDisappear
    case viewSafeAreaInsetsDidChange
    case viewLayoutMarginsDidChange
    case traitCollectionDidChange
    case viewWillTransition
    case willMoveToParent
    case didMoveToParent
    case didReceiveMemoryWarning

    /**
     * The UIViewController selector of the event.
     */
    var selector: Selector {
        switch self {
        case .viewDidLoad: return #selector(UIViewController.viewDidLoad)
        case .viewWillAppear: return #selector(UIViewController.viewWillAppear(_:))
        case .viewIsAppearing: return NSSelectorFromString("viewIsAppearing:")
        case .viewDidAppear: return #selector(UIViewController.viewDidAppear(_:))
        case .viewWillLayoutSubviews: return #selector(UIViewController.viewWillLayoutSubviews)
        case .viewDidLayoutSubviews: return #selector(UIViewController.viewDidLayoutSubviews)
        case .viewWillDisappear: return #selector(UIViewController.viewWillDisappear(_:))
        case .viewDidDisappear: return #selector(UIViewController.viewDidDisappear(_:))
        case .viewSafeAreaInsetsDidChange: return #selector(UIViewController.viewSafeAreaInsetsDidChange)
        case .viewLayoutMarginsDidChange: return #selector(UIViewController.viewLayoutMarginsDidChange)
        // Deprecated in iOS 17 but still called; reached by name so it does not warn.
        case .traitCollectionDidChange: return NSSelectorFromString("traitCollectionDidChange:")
        case .viewWillTransition: return #selector(UIViewController.viewWillTransition(to:with:))
        case .willMoveToParent: return #selector(UIViewController.willMove(toParent:))
        case .didMoveToParent: return #selector(UIViewController.didMove(toParent:))
        case .didReceiveMemoryWarning: return #selector(UIViewController.didReceiveMemoryWarning)
        }
    }
}

/**
 * When a lifecycle block runs, relative to the `super` call that reaches UIKit's implementation.
 */
public enum CYLLifecycleTiming: Int, CaseIterable {
    /**
     * At the top, right before UIKit's implementation runs.
     */
    case beforeSuper
    /**
     * At the top, right after UIKit's implementation returns (the default).
     */
    case afterSuper
    /**
     * At the bottom, after the owner's override. Automatic only for classes that do not override the method; otherwise
     * dispatched by the owner (`cylPerformLifecycle` or `cylInvokeLifecycleCallbacks`).
     */
    case end
}

/**
 * What a lifecycle (or dealloc) block is told about the event; the fields that do not apply to the event are nil.
 */
public struct CYLLifecycleInfo {
    /**
     * The event; nil for a dealloc block.
     */
    public internal(set) var event: CYLLifecycleEvent?
    /**
     * The timing of this run (`.end` for a dealloc block).
     */
    public internal(set) var timing: CYLLifecycleTiming
    /**
     * The `animated` argument of the appearance events.
     */
    public var animated: Bool?
    /**
     * The new size of `viewWillTransition`.
     */
    public var size: CGSize?
    /**
     * The coordinator of `viewWillTransition`.
     */
    public var transitionCoordinator: UIViewControllerTransitionCoordinator?
    /**
     * The previous trait collection of `traitCollectionDidChange`: compare it with the owner's to see what changed.
     */
    public var previousTraitCollection: UITraitCollection?
    /**
     * The parent of `willMoveToParent` / `didMoveToParent` (nil when removed from a parent).
     */
    public var parent: UIViewController?

    /**
     * True for a dealloc block.
     */
    public var isDealloc: Bool { event == nil }

    /**
     * The arguments of a manual dispatch; the event and the timing are filled in by the dispatcher.
     */
    public init(animated: Bool? = nil, size: CGSize? = nil, transitionCoordinator: UIViewControllerTransitionCoordinator? = nil,
                previousTraitCollection: UITraitCollection? = nil, parent: UIViewController? = nil) {
        self.event = nil
        self.timing = .afterSuper
        self.animated = animated
        self.size = size
        self.transitionCoordinator = transitionCoordinator
        self.previousTraitCollection = previousTraitCollection
        self.parent = parent
    }

    static var dealloc: CYLLifecycleInfo {
        var info = CYLLifecycleInfo()
        info.timing = .end
        return info
    }
}

/**
 * Gives every NSObject the typed lifecycle API: the block receives the owner with its own type, as
 * `CYLViewDidLayoutSubViewsBlock = (CYLTabBarController) -> Void` does in CYLTabBarController.
 */
public protocol CYLLifecycleCallbackOwner: AnyObject {}

extension NSObject: CYLLifecycleCallbackOwner {}

extension CYLLifecycleCallbackOwner where Self: NSObject {

    /**
     * Adds a block run at `event`, at `timing`. Several blocks per object and event run in the order they were added.
     * Use the `owner` parameter instead of capturing `self` (a block stored on `self` that captures it is a cycle).
     *
     * - Parameters:
     *   - event: the lifecycle event.
     *   - timing: before `super`, after `super` (default) or at the end of the method.
     *   - invokeOnce: run once until `cylRearmLifecycleCallbacks(for:)` (or a replacement under the same key).
     *   - key: replaces the block added before under the same key.
     *   - callback: the owner, the identifier of this block and the info of the event.
     * - Returns: The identifier, for `cylCancelLifecycleCallback(identifier:)`.
     */
    @discardableResult
    public func cylAddLifecycleCallback(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming = .afterSuper,
                                         invokeOnce: Bool = false, key: String? = nil,
                                         callback: @escaping (_ owner: Self, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void) -> UInt {
        let (identifier, model) = cylMakeCallbackIdentifierAndModel()
        model.addLifecycleCallback({ owner, identifier, info in
            if let typedOwner = owner as? Self {
                callback(typedOwner, identifier, info)
            }
        }, identifier: identifier, event: event, timing: timing, invokeOnce: invokeOnce, key: key)
        if let viewController = self as? UIViewController {
            CYLLifecycleHooks.installIfNeeded()
            CYLLifecycleHooks.warnIfEndNeedsManualDispatch(viewController, event: event, timing: timing, model: model)
        }
        return identifier
    }
}

extension NSObject {

    /**
     * Cancels one lifecycle block.
     *
     * - Returns: Whether a block had this identifier.
     */
    @discardableResult
    public func cylCancelLifecycleCallback(identifier: UInt) -> Bool {
        cylCallbackModel(create: false)?.removeLifecycleCallback(identifier: identifier) ?? false
    }

    /**
     * Cancels the block added under `key`.
     *
     * - Returns: Whether a block had this key.
     */
    @discardableResult
    public func cylCancelLifecycleCallback(key: String) -> Bool {
        guard let model = cylCallbackModel(create: false), let identifier = model.lifecycleIdentifier(key: key) else { return false }
        return model.removeLifecycleCallback(identifier: identifier)
    }

    /**
     * Lets the invoke-once block added under `key` run once more.
     *
     * - Returns: Whether a block had this key.
     */
    @discardableResult
    public func cylRearmLifecycleCallback(key: String) -> Bool {
        guard let model = cylCallbackModel(create: false), let identifier = model.lifecycleIdentifier(key: key) else { return false }
        return model.rearmLifecycleCallback(identifier: identifier)
    }

    /**
     * Cancels the blocks of `event` added without a key, of one timing or of all timings (nil). Keyed blocks belong to
     * whoever holds the key (`cylCancelLifecycleCallback(key:)`), so an app cannot remove a library's blocks this way.
     */
    public func cylCancelAllLifecycleCallbacks(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil) {
        cylCallbackModel(create: false)?.removeAllLifecycleCallbacks(event: event, timing: timing)
    }

    /**
     * Lets the invoke-once blocks of `event` added without a key (one timing or all) run once more; keyed blocks are
     * re-armed with `cylRearmLifecycleCallback(key:)`. Touches no view: call `view.setNeedsLayout()` yourself when a
     * layout event should come.
     */
    public func cylRearmLifecycleCallbacks(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil) {
        cylCallbackModel(create: false)?.rearmLifecycleCallbacks(event: event, timing: timing)
    }

    /**
     * Declares that the owner dispatches `events` at `timings` itself (`cylInvokeLifecycleCallbacks`); the automatic
     * hook then skips those points. Other timings of the same events stay automatic.
     */
    public func cylSetManualLifecycleDispatch(_ manual: Bool, for events: Set<CYLLifecycleEvent>,
                                               timings: Set<CYLLifecycleTiming> = Set(CYLLifecycleTiming.allCases)) {
        cylCallbackModel(create: true)?.setManualDispatch(manual, events: events, timings: timings)
    }

    /**
     * Runs an override so that its `.end` blocks fire after its body: `callSuper`, `body`, then `.end`.
     * On a view controller, `.beforeSuper` / `.afterSuper` come from the automatic hook inside `callSuper`, and `.end`
     * fires only at the outermost `cylPerformLifecycle` of the event (a subclass and its superclass can both use it)
     * and not when the owner declared `.end` manual. Other owners (no hook) get all three timings from the outermost call.
     *
     *     override func viewDidLoad() {
     *         cylPerformLifecycle(.viewDidLoad, callSuper: { super.viewDidLoad() }) {
     *             // the override's own work
     *         }
     *     }
     */
    public func cylPerformLifecycle(_ event: CYLLifecycleEvent, info: CYLLifecycleInfo = CYLLifecycleInfo(),
                                     callSuper: () -> Void, body: () -> Void = {}) {
        guard let model = cylCallbackModel(create: true) else { return }
        let outermost = !model.isPerforming(event)
        let hooked = self is UIViewController
        model.beginPerforming(event)
        defer { model.endPerforming(event) }
        if outermost && !hooked {
            cylFireLifecycle(event, timing: .beforeSuper, info: info)
        }
        callSuper()
        if outermost && !hooked {
            cylFireLifecycle(event, timing: .afterSuper, info: info)
        }
        body()
        if outermost && !model.isManualDispatch(event, timing: .end) {
            cylFireLifecycle(event, timing: .end, info: info)
        }
    }

    /**
     * Runs the blocks of `event` at `timing` now. On a view controller, declare the point manual first
     * (`cylSetManualLifecycleDispatch`), or the automatic hook runs the same blocks too (asserted in debug builds).
     */
    public func cylInvokeLifecycleCallbacks(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming,
                                             info: CYLLifecycleInfo = CYLLifecycleInfo()) {
        guard let model = cylCallbackModel(create: false) else { return }
        assert(!(self is UIViewController) || model.isManualDispatch(event, timing: timing) || model.isPerforming(event),
               "CYLDeallocBlockExecutor: call cylSetManualLifecycleDispatch(true, for: [.\(event)], timings: [.\(timing)]) first.")
        cylFireLifecycle(event, timing: timing, info: info)
    }

    /**
     * Runs the blocks waiting for `event` at `timing`, outside every lock, skipping blocks cancelled meanwhile.
     */
    func cylFireLifecycle(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming, info: CYLLifecycleInfo) {
        guard let model = cylCallbackModel(create: false) else { return }
        var info = info
        info.event = event
        info.timing = timing
        for (identifier, callback) in model.takeLifecycleCallbacks(event: event, timing: timing)
        where model.containsLifecycleCallback(identifier: identifier) {
            callback(self, identifier, info)
        }
    }
}
