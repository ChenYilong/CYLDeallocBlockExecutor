//
//  main.swift
//  LifecycleTests: runs on a simulator (Tests/run-lifecycle-tests.sh), prints one line per check and a RESULT line.
//
//  Copyright © 2026 https://github.com/ChenYilong . All rights reserved.
//

import UIKit
import ObjectiveC

var failures: [String] = []
var passes = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String, _ detail: @autoclosure () -> String = "") {
    if condition() {
        passes += 1
        print("PASS \(name)")
    } else {
        failures.append(name)
        print("FAIL \(name) \(detail())")
    }
}

var log: [String] = []

final class PlainViewController: UIViewController {}

final class OverridingViewController: UIViewController {
    override func viewDidLoad() {
        log.append("app-before-super")
        super.viewDidLoad()
        log.append("app-after-super")
    }
}

final class PerformingViewController: UIViewController {
    override func viewDidLoad() {
        cylPerformLifecycle(.viewDidLoad, callSuper: { super.viewDidLoad() }) {
            log.append("body")
        }
    }
}

final class RawViewController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        log.append("body")
        cylInvokeLifecycleCallbacks(for: .viewDidLayoutSubviews, timing: .end)
    }
}

class PerformBaseViewController: UIViewController {
    override func viewDidLoad() {
        cylPerformLifecycle(.viewDidLoad, callSuper: { super.viewDidLoad() }) { log.append("baseBody") }
    }
}

final class PerformSubViewController: PerformBaseViewController {
    override func viewDidLoad() {
        cylPerformLifecycle(.viewDidLoad, callSuper: { super.viewDidLoad() }) { log.append("subBody") }
    }
}

/// Like CYLTabBarController's layout: super, core body, raw .end invoke.
class CoreLayoutViewController: UIViewController {
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        cylSetManualLifecycleDispatch(true, for: [.viewDidLayoutSubviews], timings: [.end])
        cylAddLifecycleCallback(for: .viewDidLayoutSubviews, key: "core.after") { _, _, _ in log.append("core-after") }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        log.append("core-body")
        cylInvokeLifecycleCallbacks(for: .viewDidLayoutSubviews, timing: .end)
    }
}

final class AppPerformLayoutViewController: CoreLayoutViewController {
    override func viewDidLayoutSubviews() {
        cylPerformLifecycle(.viewDidLayoutSubviews, callSuper: { super.viewDidLayoutSubviews() }) { log.append("app-body") }
    }
}

/// Like CYLTabBarController: no override, registers in init; an app subclass overrides.
class CoreLikeViewController: UIViewController {
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        cylAddLifecycleCallback(for: .viewWillAppear, key: "core.viewWillAppear") { _, _, _ in log.append("core") }
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class AppSubclassViewController: CoreLikeViewController {
    override func viewWillAppear(_ animated: Bool) {
        log.append("app-before")
        super.viewWillAppear(animated)
        log.append("app-after")
    }
}

/// An exchange-style swizzle like CYLTabBarController's installAutomaticNavigationSetting.
var exchangeCalls = 0
extension UIViewController {
    @objc dynamic func cylTest_exchangedViewDidAppear(_ animated: Bool) {
        cylTest_exchangedViewDidAppear(animated)
        exchangeCalls += 1
    }
    static func cylTest_installExchange() {
        if let a = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidAppear(_:))),
           let b = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.cylTest_exchangedViewDidAppear(_:))) {
            method_exchangeImplementations(a, b)
        }
    }
}

final class KVOTarget: NSObject {
    @objc dynamic var value = 0
}

final class KVOObserverViewController: UIViewController {
    let target: KVOTarget
    init(target: KVOTarget) {
        self.target = target
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        // README scenario: add in viewDidLoad, remove at dealloc, no flag.
        let observed = target
        observed.addObserver(self, forKeyPath: "value", options: .new, context: nil)
        cylWillDealloc(key: "kvo.value") { owner, _, _ in
            observed.removeObserver(owner.takeUnretainedValue() as! NSObject, forKeyPath: "value")
        }
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {}
}

var executeRuns: [String] = []

/// The 1.2.0 API is deprecated on purpose: the test calls it from a deprecated context, reached by selector, so the build has no warning.
final class DeprecatedAPICaller: NSObject {
    @available(*, deprecated)
    @objc func addThreeBlocks(_ object: NSObject) {
        object.cyl_executeAtDealloc { executeRuns.append("a") }
        object.cyl_executeAtDealloc { executeRuns.append("b") }
        object.cyl_executeAtDealloc { executeRuns.append("c") }
    }
}

/// Issue #8: a view-like observer that outlives its view controller.
final class ViewObserver: NSObject {
    unowned(unsafe) var viewController: UIViewController?
    let onDeinit: () -> Void
    init(onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
        super.init()
    }
    deinit { onDeinit() }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {}
}

func appear(_ vc: UIViewController, in window: UIWindow) {
    window.rootViewController = vc
    window.makeKeyAndVisible()
    vc.view.layoutIfNeeded()
}

func runTests(window: UIWindow) {
    // 1. Three timings on a class that does not override.
    log = []
    let plain = PlainViewController()
    for timing in CYLLifecycleTiming.allCases {
        plain.cylAddLifecycleCallback(for: .viewDidLoad, timing: timing) { _, _, info in log.append("\(info.timing)") }
    }
    plain.loadViewIfNeeded()
    check(log == ["beforeSuper", "afterSuper", "end"], "automatic timings, no override", "\(log)")

    // 2. Overriding class: before/after around UIKit inside super, no automatic end.
    log = []
    let overriding = OverridingViewController()
    for timing in CYLLifecycleTiming.allCases {
        overriding.cylAddLifecycleCallback(for: .viewDidLoad, timing: timing) { _, _, info in log.append("\(info.timing)") }
    }
    overriding.loadViewIfNeeded()
    check(log == ["app-before-super", "beforeSuper", "afterSuper", "app-after-super"], "automatic timings, override", "\(log)")

    // 3. cylPerformLifecycle: all timings, no double firing.
    log = []
    let performing = PerformingViewController()
    for timing in CYLLifecycleTiming.allCases {
        performing.cylAddLifecycleCallback(for: .viewDidLoad, timing: timing) { _, _, info in log.append("\(info.timing)") }
    }
    performing.loadViewIfNeeded()
    check(log == ["beforeSuper", "afterSuper", "body", "end"], "cylPerformLifecycle order, no double fire", "\(log)")

    // 4. Raw manual .end with automatic .afterSuper on the same event (CYLTabBarController's layout block).
    log = []
    let raw = RawViewController()
    raw.cylSetManualLifecycleDispatch(true, for: [.viewDidLayoutSubviews], timings: [.end])
    raw.cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .afterSuper) { _, _, _ in log.append("afterSuper") }
    raw.cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: true, key: "layoutBlock") { _, _, _ in log.append("end1") }
    raw.loadViewIfNeeded()
    raw.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    check(log.filter { $0 == "end1" }.count == 1, "invoke once (manual end)", "\(log)")
    check(log.filter { $0 == "afterSuper" }.count == 2 && log.filter { $0 == "body" }.count == 2, "automatic afterSuper beside manual end", "\(log)")
    check(log.prefix(3) == ["afterSuper", "body", "end1"], "manual end after the override body", "\(log)")
    log = []
    raw.cylRearmLifecycleCallback(key: "layoutBlock")
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    check(log.contains("end1"), "re-arm runs an invoke-once block again", "\(log)")
    log = []
    raw.cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: true, key: "layoutBlock") { _, _, _ in log.append("end2") }
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    check(log.contains("end2") && !log.contains("end1"), "replace by key (and replacement re-arms)", "\(log)")

    // 5. Several blocks, order, identifiers, typed owner, cancel one, cancel all.
    log = []
    let order = PlainViewController()
    var ids: [UInt] = []
    var ownerTyped = false
    for index in 0..<3 {
        ids.append(order.cylAddLifecycleCallback(for: .viewWillLayoutSubviews) { owner, identifier, _ in
            ownerTyped = owner === order
            log.append("\(index):\(identifier)")
        })
    }
    order.cylCancelLifecycleCallback(identifier: ids[1])
    order.loadViewIfNeeded()
    order.view.setNeedsLayout(); order.view.layoutIfNeeded()
    check(log.first == "0:\(ids[0])" && log.dropFirst().first == "2:\(ids[2])" && !log.contains("1:\(ids[1])"),
          "order by identifier, cancel one", "\(log) \(ids)")
    check(ownerTyped, "typed owner")
    log = []
    order.cylCancelAllLifecycleCallbacks(for: .viewWillLayoutSubviews)
    order.view.setNeedsLayout(); order.view.layoutIfNeeded()
    check(log.isEmpty, "cancel all", "\(log)")

    // 6. A block that cancels a later one, and a block that adds a block.
    log = []
    let mutating = PlainViewController()
    var laterID: UInt = 0
    mutating.cylAddLifecycleCallback(for: .viewDidLoad) { owner, _, _ in
        log.append("first")
        owner.cylCancelLifecycleCallback(identifier: laterID)
        owner.cylAddLifecycleCallback(for: .viewWillLayoutSubviews) { _, _, _ in log.append("added") }
    }
    laterID = mutating.cylAddLifecycleCallback(for: .viewDidLoad) { _, _, _ in log.append("later") }
    mutating.loadViewIfNeeded()
    mutating.view.setNeedsLayout(); mutating.view.layoutIfNeeded()
    check(log.first == "first" && !log.contains("later") && log.contains("added"), "add/cancel from inside a block", "\(log)")

    // 7. Core-like class registering in init, app subclass overriding.
    log = []
    let app = AppSubclassViewController(nibName: nil, bundle: nil)
    app.loadViewIfNeeded()
    app.beginAppearanceTransition(true, animated: false); app.endAppearanceTransition()
    check(log == ["app-before", "core", "app-after"], "core block inside an app subclass's super call", "\(log)")

    // 8. Appearance events with info, window-hosted; exchange-style swizzle installed after the hooks.
    let exchangeFirst = CommandLine.arguments.contains("-exchangeFirst")
    if !exchangeFirst { UIViewController.cylTest_installExchange() }
    print("INFO exchange swizzle installed \(exchangeFirst ? "before" : "after") the lifecycle hooks")
    log = []
    exchangeCalls = 0
    let appearing = PlainViewController()
    var animatedFlags: [Bool?] = []
    for event in [CYLLifecycleEvent.viewWillAppear, .viewIsAppearing, .viewDidAppear] {
        appearing.cylAddLifecycleCallback(for: event) { _, _, info in log.append("\(event)"); animatedFlags.append(info.animated) }
    }
    appearing.loadViewIfNeeded()
    appearing.beginAppearanceTransition(true, animated: true); appearing.endAppearanceTransition()
    check(log.contains("viewWillAppear") && log.contains("viewDidAppear"), "appearance events fire", "\(log)")
    check(log.filter { $0 == "viewDidAppear" }.count == 1 && exchangeCalls >= 1, "exchange swizzle after hooks: one fire, exchange runs", "\(log) exchange=\(exchangeCalls)")
    check(animatedFlags.allSatisfy { $0 != nil }, "info.animated set")
    print("INFO viewIsAppearing fired: \(log.contains("viewIsAppearing"))")

    // 9. Disappearance.
    log = []
    let next = PlainViewController()
    appearing.cylAddLifecycleCallback(for: .viewWillDisappear) { _, _, _ in log.append("willDisappear") }
    appearing.cylAddLifecycleCallback(for: .viewDidDisappear) { _, _, _ in log.append("didDisappear") }
    appearing.beginAppearanceTransition(false, animated: false); appearing.endAppearanceTransition()
    check(log == ["willDisappear", "didDisappear"], "disappearance events", "\(log)")
    _ = next

    // 10. Trait change (dark mode skin hook), safe area, layout margins.
    log = []
    var previous: UITraitCollection?
    appear(appearing, in: window)
    appearing.cylAddLifecycleCallback(for: .traitCollectionDidChange) { owner, _, info in
        previous = info.previousTraitCollection
        log.append("trait:\(owner.traitCollection.userInterfaceStyle.rawValue)")
    }
    appearing.cylAddLifecycleCallback(for: .viewSafeAreaInsetsDidChange) { _, _, _ in log.append("safeArea") }
    appearing.cylAddLifecycleCallback(for: .viewLayoutMarginsDidChange) { _, _, _ in log.append("margins") }
    window.overrideUserInterfaceStyle = .dark
    window.layoutIfNeeded(); appearing.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    check(log.contains("trait:2") && previous != nil, "traitCollectionDidChange with previous traits", "\(log)")
    appearing.additionalSafeAreaInsets = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
    appearing.view.layoutIfNeeded()
    check(log.contains("safeArea"), "viewSafeAreaInsetsDidChange", "\(log)")
    appearing.view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 3, leading: 33, bottom: 3, trailing: 33)
    appearing.view.layoutIfNeeded()
    check(log.contains("margins"), "viewLayoutMarginsDidChange", "\(log)")

    // 11. Parent moves.
    log = []
    let child = PlainViewController()
    var parents: [UIViewController?] = []
    child.cylAddLifecycleCallback(for: .willMoveToParent) { _, _, info in log.append("will"); parents.append(info.parent) }
    child.cylAddLifecycleCallback(for: .didMoveToParent) { _, _, info in log.append("did"); parents.append(info.parent) }
    appearing.addChild(child); child.didMove(toParent: appearing)
    check(log == ["will", "did"] && parents.allSatisfy { $0 === appearing }, "willMove/didMove with parent", "\(log)")

    // 12. Memory warning.
    log = []
    appearing.cylAddLifecycleCallback(for: .didReceiveMemoryWarning) { _, _, _ in log.append("memory") }
    UIApplication.shared.perform(NSSelectorFromString("_performMemoryWarning"))
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    if !log.contains("memory") { appearing.didReceiveMemoryWarning() }
    check(log.contains("memory"), "didReceiveMemoryWarning", "\(log)")


    // 14. Dealloc aligned: shared identifiers, order, info, keyed replacement, 1.3.0 API.
    log = []
    autoreleasepool {
        let object = PlainViewController()
        let a = object.cylWillDealloc { _, identifier in log.append("old:\(identifier)") }
        let b = object.cylAddLifecycleCallback(for: .viewDidLoad) { _, _, _ in }
        let c = object.cylWillDealloc(callback: { _, identifier, info in log.append("new:\(identifier):\(info.isDealloc):\(info.timing)") })
        object.cylWillDealloc(key: "k") { _, _, _ in log.append("key1") }
        object.cylWillDealloc(key: "k") { _, _, _ in log.append("key2") }
        check(a < b && b < c, "one identifier sequence for dealloc and lifecycle", "\(a) \(b) \(c)")
    }
    check(log.count == 3 && log[0].hasPrefix("old:") && log[1] == "new:3:true:end" && log[2] == "key2", "dealloc order, info, keyed replacement", "\(log)")

    // 15. README KVO scenario: viewDidLoad never runs, dealloc does; and the normal path.
    let kvoTarget = KVOTarget()
    autoreleasepool { _ = KVOObserverViewController(target: kvoTarget) }
    check(kvoTarget.observationInfo == nil, "KVO: no viewDidLoad, nothing to remove")
    var observedWhileAlive = false
    autoreleasepool {
        let observer = KVOObserverViewController(target: kvoTarget)
        observer.loadViewIfNeeded()
        observedWhileAlive = kvoTarget.observationInfo != nil
    }
    kvoTarget.value = 1
    check(observedWhileAlive && kvoTarget.observationInfo == nil, "KVO: observer removed by the dealloc block (README, no flag)")

    // 16. Nested cylPerformLifecycle (base and subclass).
    log = []
    let nested = PerformSubViewController()
    for timing in CYLLifecycleTiming.allCases {
        nested.cylAddLifecycleCallback(for: .viewDidLoad, timing: timing) { _, _, info in log.append("\(info.timing)") }
    }
    nested.loadViewIfNeeded()
    check(log == ["beforeSuper", "afterSuper", "baseBody", "subBody", "end"], "nested cylPerformLifecycle fires each timing once", "\(log)")

    // 17. Core override with raw .end, app subclass with cylPerformLifecycle.
    log = []
    let coreApp = AppPerformLayoutViewController(nibName: nil, bundle: nil)
    coreApp.cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end) { _, _, _ in log.append("end-block") }
    coreApp.loadViewIfNeeded()
    log = []
    coreApp.view.setNeedsLayout(); coreApp.view.layoutIfNeeded()
    check(log == ["core-after", "core-body", "end-block", "app-body"], "core raw .end inside an app's cylPerformLifecycle", "\(log)")

    // 18. UIKit subclasses.
    for (name, controller) in [("UITableViewController", UITableViewController(style: .insetGrouped) as UIViewController),
                               ("UINavigationController", UINavigationController(rootViewController: UIViewController()))] {
        log = []
        controller.cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .afterSuper) { _, _, _ in log.append("after") }
        controller.cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end) { _, _, _ in log.append("end") }
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 300, height: 500)
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        print("INFO \(name): viewDidLayoutSubviews .afterSuper fired: \(log.contains("after")), .end fired: \(log.contains("end"))")
        log = []
        controller.cylAddLifecycleCallback(for: .viewWillAppear) { _, _, _ in log.append("willAppear") }
        controller.beginAppearanceTransition(true, animated: false); controller.endAppearanceTransition()
        check(log.contains("willAppear"), "\(name): viewWillAppear .afterSuper fires", "\(log)")
    }

    // 19. Core / app isolation: the app cancels all on a core-like subclass; keyed core blocks survive.
    log = []
    let isolationTarget = KVOTarget()
    autoreleasepool {
        let isolated = PlainViewController()
        let observed = isolationTarget
        isolated.cylAddLifecycleCallback(for: .viewWillLayoutSubviews, key: "cyl.core.willLayout") { _, _, _ in log.append("core") }
        isolated.cylAddLifecycleCallback(for: .viewWillLayoutSubviews) { _, _, _ in log.append("app") }
        observed.addObserver(isolated, forKeyPath: "value", options: .new, context: nil)
        isolated.cylWillDealloc(key: "cyl.core.kvo") { owner, _, _ in
            observed.removeObserver(owner.takeUnretainedValue() as! NSObject, forKeyPath: "value")
        }
        // The app's broad calls.
        isolated.cylCancelAllLifecycleCallbacks(for: .viewWillLayoutSubviews)
        isolated.cylCancelAllDeallocCallbacks()
        isolated.loadViewIfNeeded()
        isolated.view.setNeedsLayout(); isolated.view.layoutIfNeeded()
        check(log.contains("core") && !log.contains("app"), "isolation: app cancel-all keeps the core's keyed blocks", "\(log)")
    }
    check(isolationTarget.observationInfo == nil, "isolation: app cancel-all keeps the core's keyed dealloc block")

    // 20. The core re-arms its block by key; the app's run-once block does not run again.
    log = []
    let rearmed = PlainViewController()
    rearmed.cylAddLifecycleCallback(for: .viewWillLayoutSubviews, invokeOnce: true, key: "cyl.core.layoutBlock") { _, _, _ in log.append("core") }
    rearmed.cylAddLifecycleCallback(for: .viewWillLayoutSubviews, invokeOnce: true) { _, _, _ in log.append("app") }
    rearmed.loadViewIfNeeded()
    rearmed.view.setNeedsLayout(); rearmed.view.layoutIfNeeded()
    log = []
    rearmed.cylRearmLifecycleCallback(key: "cyl.core.layoutBlock")
    rearmed.view.setNeedsLayout(); rearmed.view.layoutIfNeeded()
    check(log == ["core"], "isolation: core re-arms by key, app's run-once block stays fired", "\(log)")
    log = []
    rearmed.cylRearmLifecycleCallbacks(for: .viewWillLayoutSubviews)
    rearmed.view.setNeedsLayout(); rearmed.view.layoutIfNeeded()
    check(log == ["app"], "isolation: re-arm by event skips keyed blocks", "\(log)")
    log = []
    check(rearmed.cylCancelLifecycleCallback(key: "cyl.core.layoutBlock"), "cancel by key returns true")
    rearmed.cylRearmLifecycleCallbacks(for: .viewWillLayoutSubviews)
    rearmed.view.setNeedsLayout(); rearmed.view.layoutIfNeeded()
    check(log == ["app"], "cancel by key removes only that block", "\(log)")
    let deallocKeyed = NSObject()
    deallocKeyed.cylWillDealloc(key: "k") { _, _, _ in log.append("never") }
    check(deallocKeyed.cylCancelDeallocCallback(key: "k") && !deallocKeyed.cylCancelDeallocCallback(key: "k"), "cancel dealloc block by key")

    // 21. Issue #3: cyl_executeAtDealloc several times on one object: nothing runs early, each block runs once at dealloc.
    executeRuns = []
    autoreleasepool {
        let multi = NSObject()
        _ = DeprecatedAPICaller().perform(NSSelectorFromString("addThreeBlocks:"), with: multi)
        check(executeRuns.isEmpty, "issue #3: cyl_executeAtDealloc x3, no block runs when a later one is added", "\(executeRuns)")
    }
    check(executeRuns.sorted() == ["a", "b", "c"], "issue #3: cyl_executeAtDealloc x3, every block runs exactly once at dealloc", "\(executeRuns)")
    var willDeallocRuns: [String] = []
    autoreleasepool {
        let multi = NSObject()
        for name in ["a", "b", "c"] {
            multi.cylWillDealloc { _, _ in willDeallocRuns.append(name) }
            check(willDeallocRuns.isEmpty, "issue #3: cylWillDealloc(selfCallback:) adding \(name) runs no block")
        }
    }
    check(willDeallocRuns == ["a", "b", "c"], "issue #3: cylWillDealloc(selfCallback:) x3 runs every block exactly once, in order", "\(willDeallocRuns)")

    // 22. Issue #5: identifiers ascend from 1, 0 is never returned, cancel returns true once and then false.
    let identified = NSObject()
    let identifiers = (0..<3).map { _ in identified.cylWillDealloc { _, _ in log.append("identified") } }
    check(identifiers == [1, 2, 3] && !identifiers.contains(cylDeallocCallbackIllegalIdentifier), "issue #5: identifiers ascend from 1, never 0", "\(identifiers)")
    check(identified.cylCancelDeallocCallback(identifier: identifiers[1]) && !identified.cylCancelDeallocCallback(identifier: identifiers[1]),
          "issue #5: cancel(identifier:) returns true once, then false")
    check(!identified.cylCancelDeallocCallback(identifier: cylDeallocCallbackIllegalIdentifier), "issue #5: cancel(identifier: 0) returns false")
    // Cancel the later tasks by comparing identifiers: only the earlier block runs.
    var cancelLater: [String] = []
    autoreleasepool {
        let object = NSObject()
        var taskIDs: [UInt] = []
        for name in ["first", "second", "third"] {
            taskIDs.append(object.cylWillDealloc { _, _ in cancelLater.append(name) })
        }
        let threshold = taskIDs[0]
        let cancelled = taskIDs.filter { $0 > threshold }.map { object.cylCancelDeallocCallback(identifier: $0) }
        check(cancelled == [true, true], "issue #5: cancelling every identifier above the first returns true", "\(cancelled)")
    }
    check(cancelLater == ["first"], "issue #5: cancelled later tasks do not run, the earlier one does", "\(cancelLater)")

    // 23. Issue #8: an observer outlives the view controller that it observes with KVO.
    for viewLoaded in [true, false] {
        let label = viewLoaded ? "view loaded" : "view not loaded"
        var blockRan = false
        var observerDeallocated = false
        var observer: ViewObserver? = ViewObserver { observerDeallocated = true }
        autoreleasepool {
            let viewController = PlainViewController()
            if viewLoaded { viewController.loadViewIfNeeded() }
            observer?.viewController = viewController
            viewController.addObserver(observer!, forKeyPath: "view", options: .new, context: nil)
            viewController.cylWillDealloc { [weak observer] owner, _ in
                blockRan = true
                guard let observer = observer else { return }
                (owner.takeUnretainedValue() as! NSObject).removeObserver(observer, forKeyPath: "view")
                observer.viewController = nil
            }
        }
        check(blockRan, "issue #8 (\(label)): the view controller's dealloc block ran")
        check(observer?.viewController == nil, "issue #8 (\(label)): the observer's view controller reference is nil")
        check(observer != nil && !observerDeallocated, "issue #8 (\(label)): the observer outlives the view controller without a crash")
        observer = nil
        check(observerDeallocated, "issue #8 (\(label)): the observer deallocates afterwards")
    }

    // 13. Size transition: rotate the scene (asynchronous), then finish.
    var sizes: [CGSize] = []
    appearing.cylAddLifecycleCallback(for: .viewWillTransition, timing: .beforeSuper) { _, _, info in
        if let size = info.size { sizes.append(size) }
    }
    if #available(iOS 16.0, *) {
        window.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
            print("INFO geometry update error: \(error)")
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        check(!sizes.isEmpty, "viewWillTransition with size (scene rotation)", "\(sizes)")
        runObservableTests(window: window)
        print("RESULT: \(failures.isEmpty ? "PASS" : "FAIL") \(passes) passed, \(failures.count) failed \(failures)")
        fflush(stdout)
        exit(failures.isEmpty ? 0 : 1)
    }
}

/// Design v5: custom events, global observers, forwarding, window moves, screen and scrolling.
func runObservableTests(window: UIWindow) {
    // Custom events: order, userInfo, key replacement, invoke once, cancel.
    log = []
    let poster = NSObject()
    let first = poster.cylAddLifecycleCallback(forCustomEvent: "cyl.badge.didShow") { owner, identifier, info in
        log.append("a \(info.customEvent ?? "-") \(info.userInfo?["value"] as? String ?? "-") \(info.isDealloc)")
    }
    poster.cylAddLifecycleCallback(forCustomEvent: "cyl.badge.didShow", invokeOnce: true, key: "once") { _, _, _ in log.append("once") }
    poster.cylAddLifecycleCallback(forCustomEvent: "cyl.badge.didShow", key: "k") { _, _, _ in log.append("k1") }
    poster.cylAddLifecycleCallback(forCustomEvent: "cyl.badge.didShow", key: "k") { _, _, _ in log.append("k2") }
    poster.cylPostLifecycleEvent("cyl.badge.didShow", userInfo: ["value": "3"])
    poster.cylPostLifecycleEvent("cyl.badge.didShow", userInfo: ["value": "4"])
    check(log == ["a cyl.badge.didShow 3 false", "once", "k2", "a cyl.badge.didShow 4 false", "k2"], "custom events: order, userInfo, invoke once, replace by key", "\(log)")
    check(poster.cylCancelLifecycleCallback(identifier: first), "custom events: cancel by identifier")
    log = []
    poster.cylPostLifecycleEvent("another")
    check(log.isEmpty, "custom events: another name does not fire")

    // Global observers: after the owner's blocks, owner type, key, cancel, custom events, never dealloc.
    CYLLifecycleCenter.reset()
    log = []
    let owned = NSObject()
    owned.cylAddLifecycleCallback(forCustomEvent: "c") { _, _, _ in log.append("own") }
    CYLLifecycleCenter.addCallback(forCustomEvent: "c") { owner, _, info in log.append("g1 \(owner === owned) \(info.customEvent ?? "-")") }
    CYLLifecycleCenter.addCallback(forCustomEvent: "c", ownerType: UIView.self) { _, _, _ in log.append("only views") }
    let removable = CYLLifecycleCenter.addCallback(forCustomEvent: "c", key: "k") { _, _, _ in log.append("removable") }
    owned.cylPostLifecycleEvent("c")
    check(log == ["own", "g1 true c", "removable"], "global observers: after the owner's blocks, owner type filter", "\(log)")
    check(CYLLifecycleCenter.cancelCallback(identifier: removable), "global observers: cancel by identifier")
    check(!CYLLifecycleCenter.cancelCallback(key: "k"), "global observers: a cancelled observer is gone")
    log = []
    do {
        let dying = NSObject()
        dying.cylWillDealloc { _, _, _ in log.append("own dealloc") }
        CYLLifecycleCenter.addCallback(for: .viewDidLoad) { _, _, _ in log.append("global at dealloc") }
    }
    check(log == ["own dealloc"], "global observers: never receive dealloc", "\(log)")

    // Forwarding.
    CYLLifecycleCenter.reset()
    log = []
    let source = NSObject()
    let target = NSObject()
    target.cylAddLifecycleCallback(for: .didEnterScreen) { _, _, _ in log.append("target enter") }
    target.cylAddLifecycleCallback(for: .didLeaveScreen) { _, _, _ in log.append("target leave") }
    target.cylAddLifecycleCallback(forCustomEvent: "cyl.badge.didShow") { _, _, _ in log.append("target badge") }
    source.cylForwardLifecycleEvents([.didEnterScreen], to: target)
    source.cylFireDerived(.didEnterScreen)
    source.cylFireDerived(.didLeaveScreen)
    check(log == ["target enter"], "forwarding: only the chosen events reach the target", "\(log)")
    log = []
    source.cylForwardLifecycleEvents(to: target)
    source.cylFireDerived(.didLeaveScreen)
    source.cylPostLifecycleEvent("cyl.badge.didShow")
    source.cylFireDerived(.didEnterScreen)
    check(log == ["target leave", "target badge", "target enter"], "forwarding: a second forward replaces the first (no double delivery)", "\(log)")

    // Window moves and screen events of a view.
    log = []
    let host = window.rootViewController?.view ?? window
    let probe = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    probe.cylAddLifecycleCallback(for: .willMoveToWindow) { _, _, info in log.append("will \(info.window == nil ? "nil" : "window")") }
    probe.cylAddLifecycleCallback(for: .didMoveToWindow) { _, _, info in log.append("did \(info.window == nil ? "nil" : "window")") }
    probe.cylAddLifecycleCallback(for: .didEnterScreen) { _, _, _ in log.append("enter") }
    probe.cylAddLifecycleCallback(for: .didLeaveScreen) { _, _, _ in log.append("leave") }
    host.addSubview(probe)
    probe.isHidden = true
    probe.isHidden = false
    probe.removeFromSuperview()
    check(log == ["will window", "did window", "enter", "leave", "enter", "will nil", "did nil", "leave"], "window moves and screen events of a view", "\(log)")

    // Scrolling: a view reports the scrolling of its scroll view; isUserScrolling follows it; a global observer pauses and resumes.
    CYLLifecycleCenter.reset()
    log = []
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let cell = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    scrollView.addSubview(cell)
    cell.cylAddLifecycleCallback(for: .scrollWillBeginDragging) { _, _, _ in log.append("begin") }
    cell.cylAddLifecycleCallback(for: .scrollDidEndDragging) { _, _, info in log.append("end drag \(info.willDecelerate ?? false)") }
    cell.cylAddLifecycleCallback(for: .scrollDidEndScrolling) { _, _, _ in log.append("end scroll") }
    CYLLifecycleCenter.addCallback(for: .scrollWillBeginDragging) { _, _, _ in log.append("pause all") }
    CYLLifecycleCenter.addCallback(for: .scrollDidEndScrolling) { _, _, _ in log.append("resume all") }
    host.addSubview(scrollView)
    check(!CYLLifecycleCenter.isUserScrolling, "isUserScrolling is false before a drag")
    let observer = CYLLifecycleSources.scrollObserver(of: scrollView)
    observer.notify(.scrollWillBeginDragging, CYLLifecycleInfo(window: nil, scrollView: scrollView))
    check(CYLLifecycleCenter.isUserScrolling, "isUserScrolling is true while dragging")
    observer.notify(.scrollDidEndDragging, CYLLifecycleInfo(window: nil, scrollView: scrollView, willDecelerate: true))
    observer.notify(.scrollDidEndScrolling, CYLLifecycleInfo(window: nil, scrollView: scrollView))
    check(!CYLLifecycleCenter.isUserScrolling, "isUserScrolling is false after scrolling ended")
    check(log == ["begin", "pause all", "end drag true", "end scroll", "resume all"], "scroll events of a view and the global pause / resume", "\(log)")
    scrollView.removeFromSuperview()

    // A flick: UIKit clears isDecelerating after the last contentOffset change, so only polling sees the end (CYLTabBarController #823).
    CYLLifecycleCenter.reset()
    log = []
    final class FlickScrollView: UIScrollView {
        var fakeDecelerating = false
        override var isDecelerating: Bool { fakeDecelerating }
        override var isDragging: Bool { false }
    }
    let flick = FlickScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    flick.contentSize = CGSize(width: 100, height: 1000)
    host.addSubview(flick)
    CYLLifecycleCenter.addCallback(for: .scrollWillBeginDragging) { _, _, _ in log.append("pause") }
    CYLLifecycleCenter.addCallback(for: .scrollDidEndScrolling) { _, _, _ in log.append("resume") }
    let flickObserver = CYLLifecycleSources.scrollObserver(of: flick)
    flickObserver.dragBegan()
    flick.fakeDecelerating = true
    flickObserver.dragEnded()
    func spin(_ seconds: TimeInterval) {   // a run loop with no source returns at once: keep it alive with a timer
        let keepAlive = Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { _ in }
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        keepAlive.invalidate()
    }
    spin(0.1)
    flick.contentOffset = CGPoint(x: 0, y: 300)   // offset changes while still decelerating
    flick.contentOffset = CGPoint(x: 0, y: 400)
    check(log == ["pause"], "a flick does not resume while it is still decelerating", "\(log)")
    flick.fakeDecelerating = false                 // no further offset change, like UIKit
    spin(0.2)
    check(log == ["pause", "resume"], "a flick resumes once the deceleration is over, without another offset change", "\(log)")
    flick.removeFromSuperview()

    // A view controller reports didEnterScreen / didLeaveScreen right after viewDidAppear / viewDidDisappear.
    log = []
    let screenController = PlainViewController()
    screenController.cylAddLifecycleCallback(for: .viewDidAppear) { _, _, _ in log.append("appear") }
    screenController.cylAddLifecycleCallback(for: .didEnterScreen) { _, _, _ in log.append("enter") }
    screenController.cylAddLifecycleCallback(for: .viewDidDisappear) { _, _, _ in log.append("disappear") }
    screenController.cylAddLifecycleCallback(for: .didLeaveScreen) { _, _, _ in log.append("leave") }
    screenController.beginAppearanceTransition(true, animated: false)
    screenController.endAppearanceTransition()
    screenController.beginAppearanceTransition(false, animated: false)
    screenController.endAppearanceTransition()
    check(log == ["appear", "enter", "disappear", "leave"], "view controller screen events follow the appearance events", "\(log)")

    // A forward does not make a global observer hear the same moment twice; whileUserScrolls pauses and resumes.
    CYLLifecycleCenter.reset()
    var heard: [String] = []
    let forwardSource = NSObject()
    let forwardTarget = NSObject()
    CYLLifecycleCenter.addCallback(for: .didEnterScreen) { owner, _, _ in heard.append(owner === forwardSource ? "source" : "target") }
    CYLLifecycleCenter.addCallback(forCustomEvent: "cyl.badge.didShow") { owner, _, _ in heard.append(owner === forwardSource ? "source" : "target") }
    forwardSource.cylForwardLifecycleEvents(to: forwardTarget)
    forwardSource.cylFireDerived(.didEnterScreen)
    forwardSource.cylPostLifecycleEvent("cyl.badge.didShow")
    check(heard == ["source", "source"], "forwarding: a global observer hears each moment once", "\(heard)")
    CYLLifecycleCenter.reset()
    var scrollCalls: [String] = []
    let cancelScroll = CYLLifecycleCenter.whileUserScrolls(pause: { scrollCalls.append("pause") }, resume: { scrollCalls.append("resume") })
    let scroller = NSObject()
    scroller.cylFireDerived(.scrollWillBeginDragging)
    scroller.cylFireDerived(.scrollDidEndScrolling)
    check(scrollCalls == ["pause", "resume"], "whileUserScrolls pauses and resumes", "\(scrollCalls)")
    cancelScroll()
    scroller.cylFireDerived(.scrollWillBeginDragging)
    check(scrollCalls == ["pause", "resume"], "whileUserScrolls: the returned function cancels both observers")
    CYLLifecycleCenter.reset()

    // Debug log: off by default, then names the owner, event, timing and the number of blocks; dealloc observers.
    CYLLifecycleLog.isEnabled = false
    var lines: [String] = []
    CYLLifecycleLog.sink = { lines.append($0) }
    let logged = NSObject()
    logged.cylAddLifecycleCallback(forCustomEvent: CYLAnimationEvent.didPause) { _, _, _ in }
    logged.cylPostLifecycleEvent(CYLAnimationEvent.didPause)
    check(lines.isEmpty, "debug log: disabled prints nothing")
    CYLLifecycleLog.isEnabled = true
    logged.cylPostLifecycleEvent(CYLAnimationEvent.didPause)
    let describe = CYLLifecycleLog.describe(logged)
    check(lines == ["[CYLLifecycle] \(describe) posts cyl.animation.didPause: 1 block(s)"], "debug log: names the owner, the event and the block count", "\(lines)")
    var destroyed: [String] = []
    let observerId = CYLLifecycleCenter.addDeallocObserver { description, info in destroyed.append("\(description) \(info.isDealloc)") }
    var dyingDescription = ""
    do {
        let dying = NSObject()
        dying.cylWillDealloc { _, _, _ in }
        dyingDescription = CYLLifecycleLog.describe(dying)
    }
    check(destroyed == ["\(dyingDescription) true"], "dealloc observer: learns that any object with blocks was destroyed", "\(destroyed)")
    check(CYLLifecycleCenter.cancelDeallocObserver(identifier: observerId), "dealloc observer: cancel")
    CYLLifecycleLog.isEnabled = false
    CYLLifecycleLog.sink = { print($0) }
    check(CYLAnimationEvent.didStart == "cyl.animation.didStart" && CYLBadgeEvent.didBecomeReady == "cyl.badge.didBecomeReady", "well-known event names")
    CYLLifecycleCenter.reset()
}

@objc(CYLTestAppDelegate)
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }
}

/// iOS 27 requires the scene life cycle.
@objc(CYLTestSceneDelegate)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        if CommandLine.arguments.contains("-exchangeFirst") {
            UIViewController.cylTest_installExchange()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            runTests(window: window)
        }
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
