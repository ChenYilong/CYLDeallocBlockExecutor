//
//  CYLLifecycleSources.swift
//  CYLDeallocBlockExecutor
//
//  Copyright © 2026 https://github.com/ChenYilong . All rights reserved.
//

import UIKit
import ObjectiveC

/**
 * The sources of the derived events (design v5): window moves of any `UIView`, visibility on screen, and user scrolling.
 *
 * - Nothing is installed until an owner (or a global observer) waits for such an event: apps that only use dealloc blocks or
 *   the view controller events pay nothing.
 * - Window hooks replace `willMove(toWindow:)` and `didMoveToWindow` on `UIView` by `method_setImplementation`, with the
 *   previous implementation captured and called, like the view controller hooks. The fast path of a view without blocks is one
 *   associated-object read.
 * - `UIScrollView.delegate` is never touched (apps, React Native and Flutter own it): the drag comes from the pan gesture
 *   recognizer's target, the end of the deceleration from KVO on `contentOffset`.
 * - Main thread only.
 */
enum CYLLifecycleSources {

    private static var windowHooksInstalled = false
    private static var visibilityKey: UInt8 = 0
    private static var scrollObserverKey: UInt8 = 0

    // MARK: - Install on demand

    /**
     * An owner got a block (or a forward) for `event`: install what the event needs, for views already in a window too.
     */
    static func eventAdded(owner: NSObject, event: CYLLifecycleEvent) {
        switch event {
        case .willMoveToWindow, .didMoveToWindow:
            if owner is UIView { installWindowHooks() }
        case .didEnterScreen, .didLeaveScreen:
            if let view = owner as? UIView {
                installWindowHooks()
                CYLVisibilityState.of(view).update()
            }
        case .scrollWillBeginDragging, .scrollDidEndDragging, .scrollDidEndScrolling:
            if let view = owner as? UIView, view.window != nil {
                observeEnclosingScrollView(of: view)
            } else if let viewController = owner as? UIViewController, viewController.isViewLoaded, viewController.view.window != nil {
                observeContentScrollView(of: viewController)
            }
        default:
            break
        }
    }

    /**
     * A global observer waits for `event`.
     */
    static func globalEventAdded(_ event: CYLLifecycleEvent) {
        switch event {
        case .willMoveToWindow, .didMoveToWindow, .didEnterScreen, .didLeaveScreen,
             .scrollWillBeginDragging, .scrollDidEndDragging, .scrollDidEndScrolling:
            installWindowHooks()
        default:
            break
        }
    }

    // MARK: - View controllers

    static func viewControllerDidAppear(_ viewController: UIViewController) {
        if viewController.cylCallbackModel(create: false) != nil || CYLLifecycleCenter.hasObservers(for: .didEnterScreen) {
            viewController.cylFireDerived(.didEnterScreen)
        }
        observeContentScrollView(of: viewController)
    }

    static func viewControllerDidDisappear(_ viewController: UIViewController) {
        if viewController.cylCallbackModel(create: false) != nil || CYLLifecycleCenter.hasObservers(for: .didLeaveScreen) {
            viewController.cylFireDerived(.didLeaveScreen)
        }
    }

    /**
     * The scroll view of a view controller (`contentScrollView(for: .top)`, else its first scroll view) reports to it, when it or a
     * global observer waits for a scroll event.
     */
    private static func observeContentScrollView(of viewController: UIViewController) {
        guard waitsForScrollEvents(viewController), viewController.isViewLoaded else { return }
        let scrollView = viewController.contentScrollView(for: .top) ?? firstScrollView(in: viewController.view)
        if let scrollView {
            viewController.cylObserveScrolling(of: scrollView)
        }
    }

    private static func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView { return scrollView }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }

    private static func waitsForScrollEvents(_ owner: NSObject) -> Bool {
        let events: [CYLLifecycleEvent] = [.scrollWillBeginDragging, .scrollDidEndDragging, .scrollDidEndScrolling]
        let model = owner.cylCallbackModel(create: false)
        return events.contains { (model?.hasLifecycleBlocks(for: $0) ?? false) || CYLLifecycleCenter.hasObservers(for: $0) }
    }

    // MARK: - Views

    private static func installWindowHooks() {
        guard !windowHooksInstalled else { return }
        windowHooksInstalled = true
        hookWillMoveToWindow()
        hookDidMoveToWindow()
    }

    private static func isInterested(_ view: UIView) -> Bool {
        view.cylCallbackModel(create: false) != nil || CYLLifecycleCenter.observesViewEvents
    }

    private static func hookWillMoveToWindow() {
        let selector = #selector(UIView.willMove(toWindow:))
        guard let method = class_getInstanceMethod(UIView.self, selector) else { return }
        typealias Original = @convention(c) (UIView, Selector, UIWindow?) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let wrapper: @convention(block) (UIView, UIWindow?) -> Void = { view, window in
            if isInterested(view) {
                view.cylFireDerived(.willMoveToWindow, info: CYLLifecycleInfo(window: window))
            }
            original(view, selector, window)
        }
        setImplementation(imp_implementationWithBlock(wrapper), for: method, selector: selector)
    }

    private static func hookDidMoveToWindow() {
        let selector = #selector(UIView.didMoveToWindow)
        guard let method = class_getInstanceMethod(UIView.self, selector) else { return }
        typealias Original = @convention(c) (UIView, Selector) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let wrapper: @convention(block) (UIView) -> Void = { view in
            original(view, selector)
            guard isInterested(view) else { return }
            view.cylFireDerived(.didMoveToWindow, info: CYLLifecycleInfo(window: view.window))
            CYLVisibilityState.of(view).update()
            if view.window != nil {
                observeEnclosingScrollView(of: view)
            }
        }
        setImplementation(imp_implementationWithBlock(wrapper), for: method, selector: selector)
    }

    /**
     * Sets `implementation` for the selector on UIView: added when UIView only inherits it, replaced otherwise.
     */
    private static func setImplementation(_ implementation: IMP, for method: Method, selector: Selector) {
        if !class_addMethod(UIView.self, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
    }

    /**
     * The nearest enclosing scroll view of `view` reports to it, when it or a global observer waits for a scroll event.
     */
    static func observeEnclosingScrollView(of view: UIView) {
        guard waitsForScrollEvents(view) else { return }
        var ancestor = view.superview
        while let current = ancestor {
            if let scrollView = current as? UIScrollView {
                view.cylObserveScrolling(of: scrollView)
                return
            }
            ancestor = current.superview
        }
    }

    // MARK: - Scrolling

    static func scrollObserver(of scrollView: UIScrollView) -> CYLScrollObserver {
        if let existing = objc_getAssociatedObject(scrollView, &scrollObserverKey) as? CYLScrollObserver {
            return existing
        }
        let observer = CYLScrollObserver(scrollView: scrollView)
        objc_setAssociatedObject(scrollView, &scrollObserverKey, observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return observer
    }
}

// MARK: - Visibility

/**
 * Whether a view is on screen: in a window, itself and its ancestors not hidden, alpha above zero, and its frame inside the window
 * and the visible rect of every enclosing scroll view. Only views that wait for the screen events have one; it re-evaluates on
 * window moves, on `isHidden` / `alpha` (KVO) and on the scrolling of the enclosing scroll view, and fires on transitions only.
 */
final class CYLVisibilityState: NSObject {

    private static var key: UInt8 = 0

    static func of(_ view: UIView) -> CYLVisibilityState {
        if let existing = objc_getAssociatedObject(view, &key) as? CYLVisibilityState {
            return existing
        }
        let state = CYLVisibilityState(view: view)
        objc_setAssociatedObject(view, &key, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }

    private weak var view: UIView?
    private var isOnScreen = false
    private var observations: [NSKeyValueObservation] = []
    private weak var observedScrollView: UIScrollView?
    private var scrollToken: NSKeyValueObservation?

    private init(view: UIView) {
        self.view = view
        super.init()
        // Views the system owns (a tab bar's buttons) are not observed with KVO: it would swap the class of an object UIKit manages.
        // They are re-evaluated at window moves, scrolling, and by `cylRefreshScreenState()` (the tab bar controller calls it when the
        // selection changes).
        guard !Self.isSystemOwned(view) else { return }
        observations.append(view.observe(\.isHidden, options: [.new]) { [weak self] _, _ in self?.update() })
        observations.append(view.observe(\.alpha, options: [.new]) { [weak self] _, _ in self?.update() })
    }

    static func isSystemOwned(_ view: UIView) -> Bool {
        var ancestor = view.superview
        while let node = ancestor {
            if node is UITabBar || node is UINavigationBar || node is UIToolbar { return true }
            ancestor = node.superview
        }
        return false
    }

    func update() {
        guard let view else { return }
        observeEnclosingScrollView(of: view)
        let visible = Self.computeVisible(view)
        guard visible != isOnScreen else { return }
        isOnScreen = visible
        view.cylFireDerived(visible ? .didEnterScreen : .didLeaveScreen)
    }

    private func observeEnclosingScrollView(of view: UIView) {
        var ancestor = view.superview
        var found: UIScrollView?
        while let current = ancestor {
            if let scrollView = current as? UIScrollView { found = scrollView; break }
            ancestor = current.superview
        }
        guard found !== observedScrollView else { return }
        observedScrollView = found
        scrollToken = found?.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in self?.update() }
    }

    static func computeVisible(_ view: UIView) -> Bool {
        guard let window = view.window else { return false }
        var current: UIView? = view
        while let node = current {
            if node.isHidden || node.alpha <= 0 { return false }
            current = node.superview
        }
        var visibleRect = view.convert(view.bounds, to: window).intersection(window.bounds)
        var ancestor = view.superview
        while let node = ancestor, !visibleRect.isNull, !visibleRect.isEmpty {
            if let scrollView = node as? UIScrollView {
                visibleRect = visibleRect.intersection(scrollView.convert(scrollView.bounds, to: window))
            }
            ancestor = node.superview
        }
        return !visibleRect.isNull && !visibleRect.isEmpty
    }
}

// MARK: - Scroll observer

/**
 * Observes one scroll view without taking over its delegate: the pan gesture recognizer's target gives the drag, KVO on
 * `contentOffset` gives the end of the deceleration (the first change with the scroll view neither dragging nor decelerating).
 * Owners subscribe weakly; the observer lives with the scroll view and stops with it.
 */
final class CYLScrollObserver: NSObject {

    private weak var scrollView: UIScrollView?
    private let subscribers = NSHashTable<NSObject>.weakObjects()
    private var offsetObservation: NSKeyValueObservation?
    private var dragging = false
    private var decelerating = false

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        super.init()
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(pan(_:)))
        offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in self?.offsetChanged() }
    }

    deinit {
        scrollView?.panGestureRecognizer.removeTarget(self, action: nil)
    }

    func subscribe(_ owner: NSObject) {
        subscribers.add(owner)
    }

    @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView else { return }
        switch recognizer.state {
        case .began:
            dragging = true
            decelerating = false
            notify(.scrollWillBeginDragging, CYLLifecycleInfo(window: nil, scrollView: scrollView))
        case .ended, .cancelled, .failed:
            guard dragging else { return }
            dragging = false
            // `isDecelerating` turns true right after the gesture ends: read it on the next run loop pass.
            DispatchQueue.main.async { [weak self] in
                guard let self, let scrollView = self.scrollView else { return }
                let willDecelerate = scrollView.isDecelerating
                self.decelerating = willDecelerate
                self.notify(.scrollDidEndDragging, CYLLifecycleInfo(window: nil, scrollView: scrollView, willDecelerate: willDecelerate))
                if !willDecelerate {
                    self.notify(.scrollDidEndScrolling, CYLLifecycleInfo(window: nil, scrollView: scrollView))
                }
            }
        default:
            break
        }
    }

    private func offsetChanged() {
        guard decelerating, let scrollView, !scrollView.isDragging, !scrollView.isDecelerating else { return }
        decelerating = false
        notify(.scrollDidEndScrolling, CYLLifecycleInfo(window: nil, scrollView: scrollView))
    }

    /**
     * Every subscriber (the cell, its sibling views, a view controller) runs its own blocks, but the global observers hear the
     * moment once, with the scroll view as the owner: a scroll view with many subviews must not make them pause an animation many
     * times.
     */
    func notify(_ event: CYLLifecycleEvent, _ info: CYLLifecycleInfo) {
        var info = info
        info.event = event
        info.timing = .afterSuper
        if let scrollView {
            CYLLifecycleCenter.dispatch(owner: scrollView, event: event, custom: nil, timing: .afterSuper, info: info)
        }
        for owner in subscribers.allObjects {
            owner.cylFireLifecycle(event, timing: .afterSuper, info: info, forwarded: true)
        }
    }
}

extension NSObject {

    /**
     * Makes `scrollView` report its scrolling to this object (`scrollWillBeginDragging`, `scrollDidEndDragging`,
     * `scrollDidEndScrolling`), without touching its delegate. View controllers do it by themselves for their content scroll view
     * once they are on screen and a scroll block waits; use this for any other scroll view. Holds `self` weakly.
     */
    public func cylObserveScrolling(of scrollView: UIScrollView) {
        CYLLifecycleSources.scrollObserver(of: scrollView).subscribe(self)
    }
}
