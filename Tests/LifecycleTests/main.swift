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
        cyl_performLifecycle(.viewDidLoad, callSuper: { super.viewDidLoad() }) {
            log.append("body")
        }
    }
}

final class RawViewController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        log.append("body")
        cyl_invokeLifecycleCallbacks(for: .viewDidLayoutSubviews, timing: .end)
    }
}

/// Like CYLTabBarController: no override, registers in init; an app subclass overrides.
class CoreLikeViewController: UIViewController {
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        cyl_addLifecycleCallback(for: .viewWillAppear, key: "core.viewWillAppear") { _, _, _ in log.append("core") }
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
        cyl_willDealloc(key: "kvo.value") { owner, _, _ in
            observed.removeObserver(owner.takeUnretainedValue() as! NSObject, forKeyPath: "value")
        }
    }
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
        plain.cyl_addLifecycleCallback(for: .viewDidLoad, timing: timing) { _, _, info in log.append("\(info.timing)") }
    }
    plain.loadViewIfNeeded()
    check(log == ["beforeSuper", "afterSuper", "end"], "automatic timings, no override", "\(log)")

    // 2. Overriding class: before/after around UIKit inside super, no automatic end.
    log = []
    let overriding = OverridingViewController()
    for timing in CYLLifecycleTiming.allCases {
        overriding.cyl_addLifecycleCallback(for: .viewDidLoad, timing: timing) { _, _, info in log.append("\(info.timing)") }
    }
    overriding.loadViewIfNeeded()
    check(log == ["app-before-super", "beforeSuper", "afterSuper", "app-after-super"], "automatic timings, override", "\(log)")

    // 3. cyl_performLifecycle: all timings, no double firing.
    log = []
    let performing = PerformingViewController()
    for timing in CYLLifecycleTiming.allCases {
        performing.cyl_addLifecycleCallback(for: .viewDidLoad, timing: timing) { _, _, info in log.append("\(info.timing)") }
    }
    performing.loadViewIfNeeded()
    check(log == ["beforeSuper", "afterSuper", "body", "end"], "cyl_performLifecycle order, no double fire", "\(log)")

    // 4. Raw manual .end with automatic .afterSuper on the same event (CYLTabBarController's layout block).
    log = []
    let raw = RawViewController()
    raw.cyl_setManualLifecycleDispatch(true, for: [.viewDidLayoutSubviews], timings: [.end])
    raw.cyl_addLifecycleCallback(for: .viewDidLayoutSubviews, timing: .afterSuper) { _, _, _ in log.append("afterSuper") }
    raw.cyl_addLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: true, key: "layoutBlock") { _, _, _ in log.append("end1") }
    raw.loadViewIfNeeded()
    raw.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    check(log.filter { $0 == "end1" }.count == 1, "invoke once (manual end)", "\(log)")
    check(log.filter { $0 == "afterSuper" }.count == 2 && log.filter { $0 == "body" }.count == 2, "automatic afterSuper beside manual end", "\(log)")
    check(log.prefix(3) == ["afterSuper", "body", "end1"], "manual end after the override body", "\(log)")
    log = []
    raw.cyl_rearmLifecycleCallbacks(for: .viewDidLayoutSubviews)
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    check(log.contains("end1"), "re-arm runs an invoke-once block again", "\(log)")
    log = []
    raw.cyl_addLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: true, key: "layoutBlock") { _, _, _ in log.append("end2") }
    raw.view.setNeedsLayout(); raw.view.layoutIfNeeded()
    check(log.contains("end2") && !log.contains("end1"), "replace by key (and replacement re-arms)", "\(log)")

    // 5. Several blocks, order, identifiers, typed owner, cancel one, cancel all.
    log = []
    let order = PlainViewController()
    var ids: [UInt] = []
    var ownerTyped = false
    for index in 0..<3 {
        ids.append(order.cyl_addLifecycleCallback(for: .viewWillLayoutSubviews) { owner, identifier, _ in
            ownerTyped = owner === order
            log.append("\(index):\(identifier)")
        })
    }
    order.cyl_cancelLifecycleCallback(identifier: ids[1])
    order.loadViewIfNeeded()
    order.view.setNeedsLayout(); order.view.layoutIfNeeded()
    check(log.first == "0:\(ids[0])" && log.dropFirst().first == "2:\(ids[2])" && !log.contains("1:\(ids[1])"),
          "order by identifier, cancel one", "\(log) \(ids)")
    check(ownerTyped, "typed owner")
    log = []
    order.cyl_cancelAllLifecycleCallbacks(for: .viewWillLayoutSubviews)
    order.view.setNeedsLayout(); order.view.layoutIfNeeded()
    check(log.isEmpty, "cancel all", "\(log)")

    // 6. A block that cancels a later one, and a block that adds a block.
    log = []
    let mutating = PlainViewController()
    var laterID: UInt = 0
    mutating.cyl_addLifecycleCallback(for: .viewDidLoad) { owner, _, _ in
        log.append("first")
        owner.cyl_cancelLifecycleCallback(identifier: laterID)
        owner.cyl_addLifecycleCallback(for: .viewWillLayoutSubviews) { _, _, _ in log.append("added") }
    }
    laterID = mutating.cyl_addLifecycleCallback(for: .viewDidLoad) { _, _, _ in log.append("later") }
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
        appearing.cyl_addLifecycleCallback(for: event) { _, _, info in log.append("\(event)"); animatedFlags.append(info.animated) }
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
    appearing.cyl_addLifecycleCallback(for: .viewWillDisappear) { _, _, _ in log.append("willDisappear") }
    appearing.cyl_addLifecycleCallback(for: .viewDidDisappear) { _, _, _ in log.append("didDisappear") }
    appearing.beginAppearanceTransition(false, animated: false); appearing.endAppearanceTransition()
    check(log == ["willDisappear", "didDisappear"], "disappearance events", "\(log)")
    _ = next

    // 10. Trait change (dark mode skin hook), safe area, layout margins.
    log = []
    var previous: UITraitCollection?
    appear(appearing, in: window)
    appearing.cyl_addLifecycleCallback(for: .traitCollectionDidChange) { owner, _, info in
        previous = info.previousTraitCollection
        log.append("trait:\(owner.traitCollection.userInterfaceStyle.rawValue)")
    }
    appearing.cyl_addLifecycleCallback(for: .viewSafeAreaInsetsDidChange) { _, _, _ in log.append("safeArea") }
    appearing.cyl_addLifecycleCallback(for: .viewLayoutMarginsDidChange) { _, _, _ in log.append("margins") }
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
    child.cyl_addLifecycleCallback(for: .willMoveToParent) { _, _, info in log.append("will"); parents.append(info.parent) }
    child.cyl_addLifecycleCallback(for: .didMoveToParent) { _, _, info in log.append("did"); parents.append(info.parent) }
    appearing.addChild(child); child.didMove(toParent: appearing)
    check(log == ["will", "did"] && parents.allSatisfy { $0 === appearing }, "willMove/didMove with parent", "\(log)")

    // 12. Memory warning.
    log = []
    appearing.cyl_addLifecycleCallback(for: .didReceiveMemoryWarning) { _, _, _ in log.append("memory") }
    UIApplication.shared.perform(NSSelectorFromString("_performMemoryWarning"))
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    if !log.contains("memory") { appearing.didReceiveMemoryWarning() }
    check(log.contains("memory"), "didReceiveMemoryWarning", "\(log)")


    // 14. Dealloc aligned: shared identifiers, order, info, keyed replacement, 1.3.0 API.
    log = []
    autoreleasepool {
        let object = PlainViewController()
        let a = object.cyl_willDealloc { _, identifier in log.append("old:\(identifier)") }
        let b = object.cyl_addLifecycleCallback(for: .viewDidLoad) { _, _, _ in }
        let c = object.cyl_willDealloc(callback: { _, identifier, info in log.append("new:\(identifier):\(info.isDealloc):\(info.timing)") })
        object.cyl_willDealloc(key: "k") { _, _, _ in log.append("key1") }
        object.cyl_willDealloc(key: "k") { _, _, _ in log.append("key2") }
        check(a < b && b < c, "one identifier sequence for dealloc and lifecycle", "\(a) \(b) \(c)")
    }
    check(log.count == 3 && log[0].hasPrefix("old:") && log[1] == "new:3:true:end" && log[2] == "key2", "dealloc order, info, keyed replacement", "\(log)")

    // 15. README KVO scenario: viewDidLoad never runs, dealloc does; and the normal path.
    let kvoTarget = KVOTarget()
    autoreleasepool { _ = KVOObserverViewController(target: kvoTarget) }
    autoreleasepool {
        let observer = KVOObserverViewController(target: kvoTarget)
        observer.loadViewIfNeeded()
        observer.loadViewIfNeeded()
    }
    kvoTarget.value = 1
    check(true, "README KVO scenario without a flag (no crash)")

    // 13. Size transition: rotate the scene (asynchronous), then finish.
    var sizes: [CGSize] = []
    appearing.cyl_addLifecycleCallback(for: .viewWillTransition, timing: .beforeSuper) { _, _, info in
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
