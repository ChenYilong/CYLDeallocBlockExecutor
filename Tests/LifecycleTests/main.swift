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

/// The 1.2.0 API is deprecated on purpose: this test calls it anyway (three expected deprecation warnings).
func executeAtDeallocThreeTimes(on object: NSObject) {
    object.cyl_executeAtDealloc { executeRuns.append("a") }
    object.cyl_executeAtDealloc { executeRuns.append("b") }
    object.cyl_executeAtDealloc { executeRuns.append("c") }
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
        executeAtDeallocThreeTimes(on: multi)
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
        print("RESULT: \(failures.isEmpty ? "PASS" : "FAIL") \(passes) passed, \(failures.count) failed \(failures)")
        fflush(stdout)
        exit(failures.isEmpty ? 0 : 1)
    }
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
