//
//  UIViewController+CYLLifecycleHooks.swift
//  CYLDeallocBlockExecutor
//
//  Copyright © 2026 https://github.com/ChenYilong . All rights reserved.
//

import UIKit
import ObjectiveC

/**
 * The automatic dispatch: each lifecycle method of UIViewController gets a wrapper that runs `.beforeSuper`, the
 * previous implementation, `.afterSuper`, and `.end` when the instance's class does not override the method. The
 * previous implementation is captured and called directly (no exchange with a named selector), so other swizzles of the
 * same methods keep working whichever is installed first. Installed once, the first time a view controller gets a
 * lifecycle block: apps that only use dealloc blocks pay nothing.
 */
enum CYLLifecycleHooks {

    private static let installation: Void = install()

    static func installIfNeeded() {
        _ = installation
    }

    /**
     * Whether the class of `viewController` (or a superclass below UIViewController) overrides the method of `event`.
     */
    static func classOverrides(_ viewController: UIViewController, event: CYLLifecycleEvent) -> Bool {
        guard let cls = object_getClass(viewController) else { return false }
        return class_getMethodImplementation(cls, event.selector) != class_getMethodImplementation(UIViewController.self, event.selector)
    }

    static func warnIfEndNeedsManualDispatch(_ viewController: UIViewController, event: CYLLifecycleEvent, timing: CYLLifecycleTiming,
                                             model: CYLCallbackModel) {
        #if DEBUG
        guard timing == .end, !model.isManualDispatch(event, timing: .end), classOverrides(viewController, event: event) else { return }
        print("CYLDeallocBlockExecutor: \(type(of: viewController)) overrides \(event.selector); its .end blocks of .\(event) need "
              + "cylPerformLifecycle(...) or cylSetManualLifecycleDispatch + cylInvokeLifecycleCallbacks in that override.")
        #endif
    }

    /**
     * The wrapper body shared by every signature.
     */
    private static func dispatch(_ viewController: UIViewController, _ event: CYLLifecycleEvent, _ info: CYLLifecycleInfo,
                                 callOriginal: () -> Void) {
        guard let model = viewController.cylCallbackModel(create: false) else {
            callOriginal()
            return
        }
        if model.dispatchesAutomatically(event, timing: .beforeSuper) {
            viewController.cylFireLifecycle(event, timing: .beforeSuper, info: info)
        }
        callOriginal()
        if model.dispatchesAutomatically(event, timing: .afterSuper) {
            viewController.cylFireLifecycle(event, timing: .afterSuper, info: info)
        }
        if model.dispatchesAutomatically(event, timing: .end), !classOverrides(viewController, event: event) {
            viewController.cylFireLifecycle(event, timing: .end, info: info)
        }
    }

    private static func install() {
        for event in [CYLLifecycleEvent.viewDidLoad, .viewWillLayoutSubviews, .viewDidLayoutSubviews, .viewSafeAreaInsetsDidChange,
                      .viewLayoutMarginsDidChange, .didReceiveMemoryWarning] {
            hookNoArgument(event)
        }
        for event in [CYLLifecycleEvent.viewWillAppear, .viewIsAppearing, .viewDidAppear, .viewWillDisappear, .viewDidDisappear] {
            hookAnimated(event)
        }
        for event in [CYLLifecycleEvent.traitCollectionDidChange, .willMoveToParent, .didMoveToParent] {
            hookObject(event)
        }
        hookTransition()
    }

    /**
     * Sets `implementation` for the selector on UIViewController: added when UIViewController only inherits it,
     * replaced otherwise.
     */
    private static func setImplementation(_ implementation: IMP, for method: Method, selector: Selector) {
        if !class_addMethod(UIViewController.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }

    private static func hookNoArgument(_ event: CYLLifecycleEvent) {
        let selector = event.selector
        guard let method = class_getInstanceMethod(UIViewController.self, selector) else { return }
        typealias Original = @convention(c) (UIViewController, Selector) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let wrapper: @convention(block) (UIViewController) -> Void = { viewController in
            dispatch(viewController, event, CYLLifecycleInfo()) { original(viewController, selector) }
        }
        setImplementation(imp_implementationWithBlock(wrapper), for: method, selector: selector)
    }

    private static func hookAnimated(_ event: CYLLifecycleEvent) {
        let selector = event.selector
        guard let method = class_getInstanceMethod(UIViewController.self, selector) else { return }
        typealias Original = @convention(c) (UIViewController, Selector, Bool) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let wrapper: @convention(block) (UIViewController, Bool) -> Void = { viewController, animated in
            dispatch(viewController, event, CYLLifecycleInfo(animated: animated)) { original(viewController, selector, animated) }
        }
        setImplementation(imp_implementationWithBlock(wrapper), for: method, selector: selector)
    }

    private static func hookObject(_ event: CYLLifecycleEvent) {
        let selector = event.selector
        guard let method = class_getInstanceMethod(UIViewController.self, selector) else { return }
        typealias Original = @convention(c) (UIViewController, Selector, AnyObject?) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let wrapper: @convention(block) (UIViewController, AnyObject?) -> Void = { viewController, argument in
            let info = event == .traitCollectionDidChange
                ? CYLLifecycleInfo(previousTraitCollection: argument as? UITraitCollection)
                : CYLLifecycleInfo(parent: argument as? UIViewController)
            dispatch(viewController, event, info) { original(viewController, selector, argument) }
        }
        setImplementation(imp_implementationWithBlock(wrapper), for: method, selector: selector)
    }

    private static func hookTransition() {
        let event = CYLLifecycleEvent.viewWillTransition
        let selector = event.selector
        guard let method = class_getInstanceMethod(UIViewController.self, selector) else { return }
        typealias Original = @convention(c) (UIViewController, Selector, CGSize, AnyObject) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let wrapper: @convention(block) (UIViewController, CGSize, AnyObject) -> Void = { viewController, size, coordinator in
            let info = CYLLifecycleInfo(size: size, transitionCoordinator: coordinator as? UIViewControllerTransitionCoordinator)
            dispatch(viewController, event, info) { original(viewController, selector, size, coordinator) }
        }
        setImplementation(imp_implementationWithBlock(wrapper), for: method, selector: selector)
    }
}
