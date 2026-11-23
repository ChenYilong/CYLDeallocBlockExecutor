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

    // Design v5 (observable moments), appended so the existing raw values stay stable. These events are derived, not hooked
    // from a UIViewController selector: window moves of any view, visibility on screen, and user scrolling. They fire at the
    // `.afterSuper` timing only (`willMoveToWindow` fires before the original `willMove(toWindow:)` and is the exception: it
    // fires at `.afterSuper` too, as a "will" notification).

    /// Any `UIView` (a control included) is about to join or leave a window; `info.window` is the new window or nil.
    case willMoveToWindow
    /// Any `UIView` joined or left a window.
    case didMoveToWindow
    /// A view or view controller became visible on screen (on a view controller: right after `viewDidAppear`).
    case didEnterScreen
    /// A view or view controller stopped being visible on screen (on a view controller: right after `viewDidDisappear`).
    case didLeaveScreen
    /// The user started dragging the scroll view of a view controller or view; `info.scrollView`.
    case scrollWillBeginDragging
    /// The user lifted the finger; `info.willDecelerate`.
    case scrollDidEndDragging
    /// The scroll view stopped for good: after deceleration, or at the end of a drag that does not decelerate.
    case scrollDidEndScrolling

    /**
     * Whether the event comes from a UIViewController method (the others are derived, see above).
     */
    var isViewControllerEvent: Bool { rawValue <= CYLLifecycleEvent.didReceiveMemoryWarning.rawValue }

    /**
     * The UIViewController selector of the event (a placeholder for the derived events, never used).
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
        case .willMoveToWindow, .didMoveToWindow, .didEnterScreen, .didLeaveScreen, .scrollWillBeginDragging, .scrollDidEndDragging,
             .scrollDidEndScrolling:
            return NSSelectorFromString("cyl_derivedEvent")
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
     * `willMoveToWindow` / `didMoveToWindow`: the window, nil when the view leaves it.
     */
    public var window: UIWindow?
    /**
     * The scroll events: the scroll view that is dragged or decelerating.
     */
    public var scrollView: UIScrollView?
    /**
     * `scrollDidEndDragging`: the scroll view keeps moving after the finger lifted.
     */
    public var willDecelerate: Bool?
    /**
     * Custom events: the name the event was posted under (nil for the built-in events and for dealloc).
     */
    public internal(set) var customEvent: String?
    /**
     * Custom events: what the poster passed along.
     */
    public var userInfo: [String: Any]?

    /**
     * True for a dealloc block.
     */
    public var isDealloc: Bool { event == nil && customEvent == nil }

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

    /**
     * The arguments of a custom event or of a derived event (window, scroll).
     */
    public init(window: UIWindow?, scrollView: UIScrollView? = nil, willDecelerate: Bool? = nil, userInfo: [String: Any]? = nil) {
        self.event = nil
        self.timing = .afterSuper
        self.window = window
        self.scrollView = scrollView
        self.willDecelerate = willDecelerate
        self.userInfo = userInfo
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
        if let viewController = self as? UIViewController, event.isViewControllerEvent {
            CYLLifecycleHooks.installIfNeeded()
            CYLLifecycleHooks.warnIfEndNeedsManualDispatch(viewController, event: event, timing: timing, model: model)
        }
        CYLLifecycleSources.eventAdded(owner: self, event: event)
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
    func cylFireLifecycle(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming, info: CYLLifecycleInfo, forwarded: Bool = false) {
        var info = info
        info.event = event
        info.timing = timing
        // The owner's own blocks, then the forwards (an object that shows through this one), then the global observers.
        if let model = cylCallbackModel(create: false) {
            let blocks = model.takeLifecycleCallbacks(event: event, timing: timing)
            CYLLifecycleLog.log("\(CYLLifecycleLog.describe(self)) \(event)/\(timing): \(blocks.count) block(s)")
            for (identifier, callback) in blocks where model.containsLifecycleCallback(identifier: identifier) {
                callback(self, identifier, info)
            }
            for target in model.forwardTargets(for: event) {
                target.cylFireLifecycle(event, timing: timing, info: info, forwarded: true)
            }
        }
        // A forwarded fire runs the target's own blocks only: the source already told the global observers once.
        if !forwarded {
            CYLLifecycleCenter.dispatch(owner: self, event: event, custom: nil, timing: timing, info: info)
        }
    }

    /**
     * Fires a derived event (window, screen, scroll) at the `.afterSuper` timing.
     */
    func cylFireDerived(_ event: CYLLifecycleEvent, info: CYLLifecycleInfo = CYLLifecycleInfo()) {
        cylFireLifecycle(event, timing: .afterSuper, info: info)
    }
}

// MARK: - Custom events and forwarding (design v5)

extension CYLLifecycleCallbackOwner where Self: NSObject {

    /**
     * Adds a block for the custom event `name`: an event the app or the library posts with `cylPostLifecycleEvent`
     * (CYLTabBarController posts the badge moments: `cyl.badge.didShow`, `cyl.badge.didClear`, `cyl.badge.didBecomeReady`,
     * `cyl.badge.animationDidStart`, `cyl.badge.animationDidStop`, and `cyl.core.tabBarItemsReady`). Same rules as the built-in
     * events: several blocks per object, run in the order they were added, identifiers shared with every other block, a key
     * replaces the block added before under it, `invokeOnce` runs once until re-armed.
     *
     * - Returns: The identifier, for `cylCancelLifecycleCallback(identifier:)`.
     */
    @discardableResult
    public func cylAddLifecycleCallback(forCustomEvent name: String, invokeOnce: Bool = false, key: String? = nil,
                                         callback: @escaping (_ owner: Self, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void) -> UInt {
        let (identifier, model) = cylMakeCallbackIdentifierAndModel()
        model.addCustomCallback({ owner, identifier, info in
            if let typedOwner = owner as? Self {
                callback(typedOwner, identifier, info)
            }
        }, identifier: identifier, custom: name, invokeOnce: invokeOnce, key: key)
        return identifier
    }
}

extension NSObject {

    /**
     * Runs the blocks of the custom event `name`: the owner's, then the forwards', then the global observers'.
     */
    public func cylPostLifecycleEvent(_ name: String, userInfo: [String: Any]? = nil) {
        cylPostLifecycleEvent(name, userInfo: userInfo, forwarded: false)
    }

    /**
     * A forwarded post runs the target's own blocks only: the source already told the global observers once, so an observer never
     * hears the same moment twice (once from the source, once from each target).
     */
    func cylPostLifecycleEvent(_ name: String, userInfo: [String: Any]?, forwarded: Bool) {
        var info = CYLLifecycleInfo()
        info.customEvent = name
        info.userInfo = userInfo
        if let model = cylCallbackModel(create: false) {
            let blocks = model.takeCustomCallbacks(name: name)
            CYLLifecycleLog.log("\(CYLLifecycleLog.describe(self)) posts \(name): \(blocks.count) block(s)")
            for (identifier, callback) in blocks where model.containsLifecycleCallback(identifier: identifier) {
                callback(self, identifier, info)
            }
            for target in model.forwardTargets(for: nil) {
                target.cylPostLifecycleEvent(name, userInfo: userInfo, forwarded: true)
            }
        }
        if !forwarded {
            CYLLifecycleCenter.dispatch(owner: self, event: nil, custom: name, timing: .afterSuper, info: info)
        }
    }

    /**
     * Forwards the lifecycle events fired on this object to `target` (all events, or `events`): a `UITabBarItem` is not a view, so
     * it receives the events of the button that shows it. The target is held weakly; forwarding to the same target again
     * replaces the earlier forward. Posted custom events are forwarded too.
     */
    public func cylForwardLifecycleEvents(_ events: Set<CYLLifecycleEvent>? = nil, to target: NSObject) {
        cylCallbackModel(create: true)?.setForward(to: target, events: events)
        if let events {
            events.forEach { CYLLifecycleSources.eventAdded(owner: self, event: $0) }
        } else {
            CYLLifecycleEvent.allCases.forEach { CYLLifecycleSources.eventAdded(owner: self, event: $0) }
        }
    }
}
