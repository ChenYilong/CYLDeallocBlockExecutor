> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# API index: declaration lines per library source file (505d187)

Extracted with regular expressions, so treat it as a navigation aid: it includes private members and can miss multi-line declarations. Format: line number, then the source line.

## CYLDeallocBlockExecutor/CYLCallbackModel.swift (352 lines)
```
15: let cylDeallocCallbackLock = NSRecursiveLock()
17: private var cylCallbackModelKey: UInt8 = 0
18: private var cylGlobalIdentifierKey: UInt8 = 0
23: typealias CYLLifecycleErasedCallback = (_ owner: AnyObject, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void
29: final class CYLCallbackModel {
31:     private struct LifecycleEntry {
41:     private struct DispatchPoint: Hashable {
46:     private let lock = NSLock()
47:     private let owner: Unmanaged<AnyObject>
48:     private var deallocCallbacks: [UInt: CYLDeallocCallback] = [:]
49:     private var deallocKeys: [String: UInt] = [:]
50:     private var lifecycleEntries: [UInt: LifecycleEntry] = [:]
51:     private var lifecycleKeys: [String: UInt] = [:]
52:     private var manualPoints: Set<DispatchPoint> = []
53:     private var performingCounts: [CYLLifecycleEvent: Int] = [:]
54:     private var forwards: [(target: Weak, events: Set<CYLLifecycleEvent>?)] = []
56:     private final class Weak {
58:         init(_ object: NSObject) { self.object = object }
61:     init(owner: AnyObject) {
65:     deinit {
81:     func addDeallocCallback(_ callback: @escaping CYLDeallocCallback, identifier: UInt, key: String? = nil) -> UInt {
98:     func removeDeallocCallback(identifier: UInt) -> Bool {
109:     func removeAllDeallocCallbacks() {
121:     func addLifecycleCallback(_ callback: @escaping CYLLifecycleErasedCallback, identifier: UInt, event: CYLLifecycleEvent,
137:     func addCustomCallback(_ callback: @escaping CYLLifecycleErasedCallback, identifier: UInt, custom: String, invokeOnce: Bool,
153:     func takeCustomCallbacks(name: String) -> [(UInt, CYLLifecycleErasedCallback)] {
170:     func setForward(to target: NSObject, events: Set<CYLLifecycleEvent>?) -> Bool {
181:     func forwardTargets(for event: CYLLifecycleEvent?) -> [NSObject] {
194:     func hasLifecycleBlocks(for event: CYLLifecycleEvent) -> Bool {
199:     func removeLifecycleCallback(identifier: UInt) -> Bool {
211:     func removeAllLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming?) {
219:     func rearmLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming?) {
226:     func lifecycleIdentifier(key: String) -> UInt? {
231:     func deallocIdentifier(key: String) -> UInt? {
236:     func rearmLifecycleCallback(identifier: UInt) -> Bool {
243:     func containsLifecycleCallback(identifier: UInt) -> Bool {
252:     func takeLifecycleCallbacks(event: CYLLifecycleEvent, timing: CYLLifecycleTiming) -> [(UInt, CYLLifecycleErasedCallback)] {
268:     func setManualDispatch(_ manual: Bool, events: Set<CYLLifecycleEvent>, timings: Set<CYLLifecycleTiming>) {
278:     func isManualDispatch(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming) -> Bool {
283:     func beginPerforming(_ event: CYLLifecycleEvent) {
288:     func endPerforming(_ event: CYLLifecycleEvent) {
294:     func isPerforming(_ event: CYLLifecycleEvent) -> Bool {
303:     func dispatchesAutomatically(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming) -> Bool {
311:     private static func matches(_ entry: LifecycleEntry, _ event: CYLLifecycleEvent, _ timing: CYLLifecycleTiming?) -> Bool {
318: extension NSObject {
323:     func cylMakeCallbackIdentifierAndModel() -> (UInt, CYLCallbackModel) {
334:     func cylCallbackModel(create: Bool) -> CYLCallbackModel? {
343:     private func cylCallbackModelLocked(create: Bool) -> CYLCallbackModel? {
```

## CYLDeallocBlockExecutor/CYLDeallocExecutor.swift (25 lines)
```
10: public typealias CYLDeallocExecutorBlock = () -> Void
13: public final class CYLDeallocExecutor: NSObject {
15:     private var deallocExecutorBlock: CYLDeallocExecutorBlock?
17:     public init(block: @escaping CYLDeallocExecutorBlock) {
22:     deinit {
```

## CYLDeallocBlockExecutor/CYLLifecycle.swift (465 lines)
```
14: public enum CYLLifecycleEvent: Int, CaseIterable {
15:     case viewDidLoad
16:     case viewWillAppear
20:     case viewIsAppearing
21:     case viewDidAppear
22:     case viewWillLayoutSubviews
23:     case viewDidLayoutSubviews
24:     case viewWillDisappear
25:     case viewDidDisappear
26:     case viewSafeAreaInsetsDidChange
27:     case viewLayoutMarginsDidChange
28:     case traitCollectionDidChange
29:     case viewWillTransition
30:     case willMoveToParent
31:     case didMoveToParent
32:     case didReceiveMemoryWarning
40:     case willMoveToWindow
42:     case didMoveToWindow
44:     case didEnterScreen
46:     case didLeaveScreen
48:     case scrollWillBeginDragging
50:     case scrollDidEndDragging
52:     case scrollDidEndScrolling
58:     case appDidBecomeActiveOnScreen
63:     var isViewControllerEvent: Bool { rawValue <= CYLLifecycleEvent.didReceiveMemoryWarning.rawValue }
68:     var selector: Selector {
96: public enum CYLLifecycleTiming: Int, CaseIterable {
100:     case beforeSuper
104:     case afterSuper
109:     case end
115: public struct CYLLifecycleInfo {
119:     public internal(set) var event: CYLLifecycleEvent?
123:     public internal(set) var timing: CYLLifecycleTiming
127:     public var animated: Bool?
131:     public var size: CGSize?
135:     public var transitionCoordinator: UIViewControllerTransitionCoordinator?
139:     public var previousTraitCollection: UITraitCollection?
143:     public var parent: UIViewController?
147:     public var window: UIWindow?
151:     public var scrollView: UIScrollView?
155:     public var willDecelerate: Bool?
159:     public internal(set) var customEvent: String?
163:     public var userInfo: [String: Any]?
168:     public var isDealloc: Bool { event == nil && customEvent == nil }
173:     public init(animated: Bool? = nil, size: CGSize? = nil, transitionCoordinator: UIViewControllerTransitionCoordinator? = nil,
187:     public init(window: UIWindow?, scrollView: UIScrollView? = nil, willDecelerate: Bool? = nil, userInfo: [String: Any]? = nil) {
196:     static var dealloc: CYLLifecycleInfo {
207: public protocol CYLLifecycleCallbackOwner: AnyObject {}
209: extension NSObject: CYLLifecycleCallbackOwner {}
211: extension CYLLifecycleCallbackOwner where Self: NSObject {
226:     public func cylAddLifecycleCallback(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming = .afterSuper,
244: extension NSObject {
252:     public func cylCancelLifecycleCallback(identifier: UInt) -> Bool {
262:     public func cylCancelLifecycleCallback(key: String) -> Bool {
273:     public func cylRearmLifecycleCallback(key: String) -> Bool {
282:     public func cylCancelAllLifecycleCallbacks(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil) {
291:     public func cylRearmLifecycleCallbacks(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil) {
299:     public func cylSetManualLifecycleDispatch(_ manual: Bool, for events: Set<CYLLifecycleEvent>,
316:     public func cylPerformLifecycle(_ event: CYLLifecycleEvent, info: CYLLifecycleInfo = CYLLifecycleInfo(),
340:     public func cylInvokeLifecycleCallbacks(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming,
351:     func cylFireLifecycle(_ event: CYLLifecycleEvent, timing: CYLLifecycleTiming, info: CYLLifecycleInfo, forwarded: Bool = false) {
375:     func cylFireDerived(_ event: CYLLifecycleEvent, info: CYLLifecycleInfo = CYLLifecycleInfo()) {
382: extension CYLLifecycleCallbackOwner where Self: NSObject {
394:     public func cylAddLifecycleCallback(forCustomEvent name: String, invokeOnce: Bool = false, key: String? = nil,
406: extension NSObject {
411:     public func cylPostLifecycleEvent(_ name: String, userInfo: [String: Any]? = nil) {
419:     func cylPostLifecycleEvent(_ name: String, userInfo: [String: Any]?, forwarded: Bool) {
443:     public func cylForwardLifecycleEvents(_ events: Set<CYLLifecycleEvent>? = nil, to target: NSObject) {
454: extension UIView {
461:     public func cylRefreshScreenState() {
```

## CYLDeallocBlockExecutor/CYLLifecycleCenter.swift (224 lines)
```
16: public enum CYLLifecycleCenter {
18:     private struct Entry {
28:     private static let lock = NSLock()
29:     private static var entries: [Entry] = []
30:     private static var nextIdentifier: UInt = 1
31:     private static let scrollingOwners = NSHashTable<AnyObject>.weakObjects()
37:     private(set) static var observesViewEvents = false
39:     private static func refreshFlags() {
48:     public static var isUserScrolling: Bool {
60:     public static func addCallback(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming = .afterSuper, ownerType: AnyClass? = nil,
75:     public static func addCallback(forCustomEvent name: String, ownerType: AnyClass? = nil, key: String? = nil,
80:     private static func add(_ prototype: Entry) -> UInt {
99:     public static func whileUserScrolls(key: String = "cyl.scroll", pause: @escaping () -> Void, resume: @escaping () -> Void) -> () -> Void {
114:     public static func cancelCallback(identifier: UInt) -> Bool {
126:     public static func cancelCallback(key: String) -> Bool {
137:     static func hasObservers(for event: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil) -> Bool {
145:     static func dispatch(owner: AnyObject, event: CYLLifecycleEvent?, custom: String?, timing: CYLLifecycleTiming, info: CYLLifecycleInfo) {
167:     private struct DeallocObserver {
173:     private static var deallocObservers: [DeallocObserver] = []
180:     public static func addDeallocObserver(key: String? = nil,
193:     public static func cancelDeallocObserver(identifier: UInt) -> Bool {
203:     static func dispatchDealloc(owner: AnyObject) {
217:     static func reset() {
```

## CYLDeallocBlockExecutor/CYLLifecycleLog.swift (49 lines)
```
17: public enum CYLLifecycleLog {
18:     public static var isEnabled = false
19:     public static var sink: (String) -> Void = { print($0) }
21:     static func log(_ message: @autoclosure () -> String) {
28:     public static func describe(_ owner: AnyObject) -> String {
36: public enum CYLAnimationEvent {
37:     public static let didStart = "cyl.animation.didStart"
38:     public static let didPause = "cyl.animation.didPause"
39:     public static let didResume = "cyl.animation.didResume"
40:     public static let didStop = "cyl.animation.didStop"
43: public enum CYLBadgeEvent {
44:     public static let didShow = "cyl.badge.didShow"
45:     public static let didClear = "cyl.badge.didClear"
46:     public static let didBecomeReady = "cyl.badge.didBecomeReady"
47:     public static let animationDidStart = "cyl.badge.animationDidStart"
48:     public static let animationDidStop = "cyl.badge.animationDidStop"
```

## CYLDeallocBlockExecutor/CYLLifecycleSources.swift (504 lines)
```
23: enum CYLLifecycleSources {
25:     private static var windowHooksInstalled = false
26:     private static var visibilityKey: UInt8 = 0
27:     private static var scrollObserverKey: UInt8 = 0
34:     static func eventAdded(owner: NSObject, event: CYLLifecycleEvent) {
62:     static func globalEventAdded(_ event: CYLLifecycleEvent) {
81:     static func observeVisibleScrollViews() {
92:     private static func observeVisibleScrollViews(in viewController: UIViewController) {
102:     private static let activeOwners = NSHashTable<NSObject>.weakObjects()
103:     private static var activeObserver: NSObjectProtocol?
109:     private static func installActiveObserver() {
121:     static func applicationDidBecomeActive() {
132:     private static func isOnScreen(_ owner: NSObject) -> Bool {
140:     private static func visibleViewControllers() -> [UIViewController] {
145:         func walk(_ viewController: UIViewController) {
160:     static func viewControllerDidAppear(_ viewController: UIViewController) {
167:     static func viewControllerDidDisappear(_ viewController: UIViewController) {
177:     private static func observeContentScrollView(of viewController: UIViewController) {
185:     private static func firstScrollView(in view: UIView) -> UIScrollView? {
193:     private static func waitsForScrollEvents(_ owner: NSObject) -> Bool {
201:     private static func installWindowHooks() {
208:     private static func isInterested(_ view: UIView) -> Bool {
212:     private static func hookWillMoveToWindow() {
215:         typealias Original = @convention(c) (UIView, Selector, UIWindow?) -> Void
226:     private static func hookDidMoveToWindow() {
229:         typealias Original = @convention(c) (UIView, Selector) -> Void
246:     private static func setImplementation(_ implementation: IMP, for method: Method, selector: Selector) {
255:     static func observeEnclosingScrollView(of view: UIView) {
270:     static func existingScrollObserver(of scrollView: UIScrollView) -> CYLScrollObserver? {
274:     static func scrollObserver(of scrollView: UIScrollView) -> CYLScrollObserver {
291: final class CYLVisibilityState: NSObject {
293:     private static var key: UInt8 = 0
295:     static func of(_ view: UIView) -> CYLVisibilityState {
305:     private var isOnScreen = false
306:     private var observations: [NSKeyValueObservation] = []
308:     private var scrollToken: NSKeyValueObservation?
310:     private init(view: UIView) {
317:     private func installObservationsIfNeeded(_ view: UIView) {
326:     func update() {
336:     static func isSystemOwned(_ view: UIView) -> Bool {
345:     private func observeEnclosingScrollView(of view: UIView) {
357:     static func computeVisible(_ view: UIView) -> Bool {
383: final class CYLScrollObserver: NSObject {
386:     private let subscribers = NSHashTable<NSObject>.weakObjects()
387:     private var offsetObservation: NSKeyValueObservation?
388:     private var dragging = false
389:     private var decelerating = false
390:     private var pollTimer: Timer?
392:     init(scrollView: UIScrollView) {
399:     deinit {
404:     func subscribe(_ owner: NSObject) {
408:     @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
416:     func dragBegan() {
424:     func dragEnded() {
443:     private func offsetChanged() {
451:     private func watchDeceleration() {
458:     private func stopWatchingDeceleration() {
463:     @objc private func decelerationTick() {
468:     private func finishDecelerationIfStopped() {
480:     func notify(_ event: CYLLifecycleEvent, _ info: CYLLifecycleInfo) {
494: extension NSObject {
501:     public func cylObserveScrolling(of scrollView: UIScrollView) {
```

## CYLDeallocBlockExecutor/NSObject+CYLDeallocBlockExecutor.swift (123 lines)
```
17: public typealias CYLDeallocSelfCallback = (_ owner: Unmanaged<AnyObject>, _ identifier: UInt) -> Void
21: public typealias CYLDeallocCallback = (_ owner: Unmanaged<AnyObject>, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void
24: public let cylDeallocCallbackIllegalIdentifier: UInt = 0
28: public let CYLDeallocCallbackIllegalIdentifier: UInt = cylDeallocCallbackIllegalIdentifier
30: private var executorsKey: UInt8 = 0
34: extension NSObject {
40:     public func cylWillDealloc(selfCallback: @escaping CYLDeallocSelfCallback) -> UInt {
49:     public func cylWillDealloc(callback: @escaping CYLDeallocCallback) -> UInt {
59:     public func cylWillDealloc(key: String, callback: @escaping CYLDeallocCallback) -> UInt {
68:     public func cylCancelDeallocCallback(identifier: UInt) -> Bool {
77:     public func cylCancelDeallocCallback(key: String) -> Bool {
84:     public func cylCancelAllDeallocCallbacks() {
93:     public func cyl_willDealloc(selfCallback: @escaping CYLDeallocSelfCallback) -> UInt {
100:     public func cyl_cancelDeallocCallback(identifier: UInt) -> Bool {
106:     public func cyl_cancelAllDeallocCallbacks() {
111:     public func cyl_executeAtDealloc(_ block: @escaping CYLDeallocExecutorBlock) {
```

## CYLDeallocBlockExecutor/UIViewController+CYLLifecycleHooks.swift (151 lines)
```
18: enum CYLLifecycleHooks {
20:     private static let installation: Void = install()
22:     static func installIfNeeded() {
29:     static func classOverrides(_ viewController: UIViewController, event: CYLLifecycleEvent) -> Bool {
34:     static func warnIfEndNeedsManualDispatch(_ viewController: UIViewController, event: CYLLifecycleEvent, timing: CYLLifecycleTiming,
46:     private static func dispatch(_ viewController: UIViewController, _ event: CYLLifecycleEvent, _ info: CYLLifecycleInfo,
55:         func dispatches(_ timing: CYLLifecycleTiming) -> Bool {
79:     private static func install() {
97:     private static func setImplementation(_ implementation: IMP, for method: Method, selector: Selector) {
103:     private static func hookNoArgument(_ event: CYLLifecycleEvent) {
106:         typealias Original = @convention(c) (UIViewController, Selector) -> Void
114:     private static func hookAnimated(_ event: CYLLifecycleEvent) {
117:         typealias Original = @convention(c) (UIViewController, Selector, Bool) -> Void
125:     private static func hookObject(_ event: CYLLifecycleEvent) {
128:         typealias Original = @convention(c) (UIViewController, Selector, AnyObject?) -> Void
139:     private static func hookTransition() {
143:         typealias Original = @convention(c) (UIViewController, Selector, CGSize, AnyObject) -> Void
```

## Android/binding/src/main/kotlin/com/chenyilong/cyldeallocblockexecutor/binding/AndroidBinding.kt (222 lines)
```
30: object AndroidBinding {
31:     private val controllers = WeakHashMap<Any, LifecycleController<*>>()
32:     private val activities = WeakHashMap<Activity, Boolean>()
33:     private var installed: Application? = null
37:     fun controllerOf(owner: Any): LifecycleController<Any> {
43:     fun install(application: Application) {
56:     fun observeWindow(owner: Any, view: View) {
60:             override fun onViewAttachedToWindow(v: View) = controller.windowMoved(true, v.windowToken ?: v)
61:             override fun onViewDetachedFromWindow(v: View) = controller.windowMoved(false)
72:     fun observeVisibility(owner: Any, view: View) {
78:             override fun onViewAttachedToWindow(v: View) {
83:             override fun onViewDetachedFromWindow(v: View) {
98:     private fun snapshot(activity: Activity): ConfigSnapshot = snapshot(activity.resources.configuration)
100:     private fun snapshot(c: Configuration): ConfigSnapshot {
111:     internal var insetsProvider: (View) -> Insets? = ::systemInsetsOf
113:     private fun insetsOf(view: View): Insets? = insetsProvider(view)
115:     private fun systemInsetsOf(view: View): Insets? {
121:     private val activityCallbacks = object : Application.ActivityLifecycleCallbacks {
122:         private val layoutListeners = WeakHashMap<Activity, ViewTreeObserver.OnGlobalLayoutListener>()
124:         override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
133:         override fun onActivityStarted(activity: Activity) {
145:         override fun onActivityResumed(activity: Activity) {
150:                 override fun onPreDraw(): Boolean {
158:         override fun onActivityPaused(activity: Activity) = controllerOf(activity).pause()
160:         override fun onActivityStopped(activity: Activity) {
168:         override fun onActivityDestroyed(activity: Activity) {
173:         override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
176:     private val fragmentCallbacks = object : FragmentManager.FragmentLifecycleCallbacks() {
177:         override fun onFragmentAttached(fm: FragmentManager, f: Fragment, context: android.content.Context) =
180:         override fun onFragmentViewCreated(fm: FragmentManager, f: Fragment, v: View, savedInstanceState: Bundle?) =
183:         override fun onFragmentStarted(fm: FragmentManager, f: Fragment) = controllerOf(f).start()
185:         override fun onFragmentResumed(fm: FragmentManager, f: Fragment) {
191:         override fun onFragmentPaused(fm: FragmentManager, f: Fragment) = controllerOf(f).pause()
192:         override fun onFragmentStopped(fm: FragmentManager, f: Fragment) = controllerOf(f).stop()
193:         override fun onFragmentDestroyed(fm: FragmentManager, f: Fragment) {
199:     private val componentCallbacks = object : ComponentCallbacks2 {
200:         override fun onConfigurationChanged(newConfig: Configuration) {
208:         override fun onTrimMemory(level: Int) {
215:         override fun onLowMemory() = fire(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)
217:         private fun fire(level: Int) {
```

## Android/binding/src/main/kotlin/com/chenyilong/cyldeallocblockexecutor/binding/RecyclerViewScrolling.kt (73 lines)
```
11: fun AndroidBinding.observeScrolling(owner: Any, recyclerView: RecyclerView): () -> Unit {
12:     val controller = controllerOf(owner)
13:     val listener = object : RecyclerView.OnScrollListener() {
14:         private var dragging = false
15:         private var settling = false
16:         override fun onScrollStateChanged(view: RecyclerView, newState: Int) {
51: fun AndroidBinding.observeScrolling(owner: Any, view: android.view.View, idleDelayMillis: Long = 150): () -> Unit {
52:     val controller = controllerOf(owner)
53:     val handler = android.os.Handler(android.os.Looper.getMainLooper())
54:     var scrolling = false
55:     val end = Runnable {
60:     val listener = android.view.ViewTreeObserver.OnScrollChangedListener {
```

## Android/core/src/main/kotlin/com/chenyilong/cyldeallocblockexecutor/LifecycleCenter.kt (128 lines)
```
11: object LifecycleCenter {
12:     private class GlobalEntry(
22:     private val lock = Any()
23:     private var entries = mutableListOf<GlobalEntry>()
24:     private var nextIdentifier = 1
25:     private val scrolling = mutableListOf<WeakReference<Any>>()
28:     val isUserScrolling: Boolean
35:     fun <T : Any> addCallback(
44:     fun <T : Any> addCustomCallback(
51:     private fun add(prototype: GlobalEntry): Int = synchronized(lock) {
63:     fun whileUserScrolls(key: String = "cyl.scroll", pause: () -> Unit, resume: () -> Unit): () -> Unit {
73:     fun cancelCallback(identifier: Int? = null, key: String? = null): Boolean {
78:     private class DeallocObserver(val identifier: Int, val key: String?, val callback: (String, LifecycleInfo) -> Unit)
80:     private var deallocObservers = mutableListOf<DeallocObserver>()
86:     fun addDeallocObserver(key: String? = null, callback: (description: String, info: LifecycleInfo) -> Unit): Int = synchronized(lock) {
93:     fun cancelDeallocObserver(identifier: Int? = null, key: String? = null): Boolean {
99:     internal fun dispatchDealloc(description: String) {
106:     fun reset() {
115:     internal fun dispatch(owner: Any, event: LifecycleEvent?, custom: String?, timing: LifecycleTiming, info: LifecycleInfo) {
```

## Android/core/src/main/kotlin/com/chenyilong/cyldeallocblockexecutor/LifecycleController.kt (163 lines)
```
37: class LifecycleController<T : Any>(owner: T) {
38:     val registry: LifecycleRegistry = LifecycleRegistry.of(owner)
39:     private var attached = false
40:     private var destroyed = false
41:     private var appearPending = false
42:     private var disappearPending = false
43:     private var lastInsets: Insets? = null
44:     private var lastConfig: ConfigSnapshot? = null
45:     private var onScreen = false
51:     private fun around(event: LifecycleEvent, info: LifecycleInfo = LifecycleInfo(), call: () -> Unit = {}) {
58:     fun attach() {
66:     fun create(initialConfig: ConfigSnapshot? = null, initialInsets: Insets? = null) {
73:     fun start() {
78:     fun resume() = around(LifecycleEvent.viewIsAppearing)
81:     fun resumedAndDrawn() {
88:     fun pause() {
93:     fun stop() {
100:     fun layout() = around(LifecycleEvent.viewDidLayoutSubviews)
103:     fun windowMoved(attached: Boolean, window: Any? = null) {
111:     fun screenVisible(visible: Boolean) {
118:     fun scrollBegan(source: Any? = null) = around(LifecycleEvent.scrollWillBeginDragging, LifecycleInfo(scrollView = source))
121:     fun scrollEndedDragging(willDecelerate: Boolean, source: Any? = null) {
127:     fun scrollEnded(source: Any? = null) = around(LifecycleEvent.scrollDidEndScrolling, LifecycleInfo(scrollView = source))
129:     fun insetsChanged(insets: Insets) {
136:     fun configurationChanged(config: ConfigSnapshot) {
151:     fun trimMemory(level: Int) = around(LifecycleEvent.didReceiveMemoryWarning, LifecycleInfo(trimLevel = level))
154:     fun destroy() {
```

## Android/core/src/main/kotlin/com/chenyilong/cyldeallocblockexecutor/LifecycleLog.kt (40 lines)
```
10: object LifecycleLog {
11:     @Volatile var enabled = false
12:     @Volatile var sink: (String) -> Unit = { println(it) }
15:     @Volatile var describer: (Any?) -> String = { owner ->
19:     fun describe(owner: Any?): String = describer(owner)
21:     internal inline fun log(message: () -> String) {
27: object AnimationEvents {
28:     const val didStart = "cyl.animation.didStart"
29:     const val didPause = "cyl.animation.didPause"
30:     const val didResume = "cyl.animation.didResume"
31:     const val didStop = "cyl.animation.didStop"
34: object BadgeEvents {
35:     const val didShow = "cyl.badge.didShow"
36:     const val didClear = "cyl.badge.didClear"
37:     const val didBecomeReady = "cyl.badge.didBecomeReady"
38:     const val animationDidStart = "cyl.badge.animationDidStart"
39:     const val animationDidStop = "cyl.badge.animationDidStop"
```

## Android/core/src/main/kotlin/com/chenyilong/cyldeallocblockexecutor/LifecycleRegistry.kt (300 lines)
```
5: private class Entry(
6:     val identifier: Int,
7:     val callback: LifecycleCallback<Any>,
8:     val event: LifecycleEvent?, // null: a teardown block or a custom event
9:     val custom: String? = null, // set: a custom event block
10:     val timing: LifecycleTiming,
11:     val invokeOnce: Boolean,
12:     val key: String?,
14:     var fired = false
15:     var cancelled = false
18: private enum class Kind { LIFECYCLE, CUSTOM, DEALLOC }
20: private fun Entry.kind(): Kind = if (event != null) Kind.LIFECYCLE else if (custom != null) Kind.CUSTOM else Kind.DEALLOC
33: class LifecycleRegistry(owner: Any) {
36:         private val registries = HashMap<Int, MutableList<LifecycleRegistry>>()
40:         fun of(owner: Any): LifecycleRegistry = synchronized(registries) {
48:     private val owner: WeakReference<Any> = WeakReference(owner)
49:     private val lock = Any()
50:     private var entries = mutableListOf<Entry>()
51:     private var nextIdentifier = 1
52:     private val manual = mutableSetOf<Pair<LifecycleEvent, LifecycleTiming>>()
53:     private val performDepth = mutableMapOf<LifecycleEvent, Int>()
54:     private var forwards = mutableListOf<Pair<WeakReference<LifecycleRegistry>, Set<LifecycleEvent>?>>()
58:     var onRegister: ((LifecycleEvent) -> Unit)? = null
62:     var hookInstalled = false
64:     val blockCount: Int get() = synchronized(lock) { entries.count { !it.cancelled } }
66:     fun hasBlocksFor(event: LifecycleEvent): Boolean =
69:     private fun drop(match: (Entry) -> Boolean) {
78:     fun <T : Any> addLifecycleCallback(
99:     fun <T : Any> addCustomCallback(
112:     fun postLifecycleEvent(name: String, userInfo: Map<String, Any?>? = null) = post(name, userInfo, forwarded = false)
118:     private fun post(name: String, userInfo: Map<String, Any?>?, forwarded: Boolean) {
142:     fun forwardLifecycleEvents(target: LifecycleRegistry, events: Set<LifecycleEvent>? = null) {
149:     private fun liveForwards(event: LifecycleEvent?): List<LifecycleRegistry> = synchronized(lock) {
155:     fun cancelLifecycleCallback(identifier: Int? = null, key: String? = null): Boolean =
159:     fun cancelAllLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming? = null) {
166:     fun rearmLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming? = null) {
174:     fun rearmLifecycleCallback(key: String) {
182:     fun <T : Any> addDeallocCallback(key: String? = null, callback: LifecycleCallback<T>): Int =
190:     fun cancelDeallocCallback(identifier: Int? = null, key: String? = null): Boolean =
194:     fun cancelAllDeallocCallbacks() {
198:     private fun cancelOne(identifier: Int?, key: String?, dealloc: Boolean): Boolean {
211:     fun runDealloc() {
229:     fun setManualLifecycleDispatch(
239:     fun isManual(event: LifecycleEvent, timing: LifecycleTiming): Boolean =
243:     fun isAutomatic(event: LifecycleEvent, timing: LifecycleTiming): Boolean =
247:     fun fireAutomatic(event: LifecycleEvent, timing: LifecycleTiming, info: LifecycleInfo = LifecycleInfo()) {
253:     fun invokeLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming, info: LifecycleInfo = LifecycleInfo()) {
265:     fun performLifecycle(
284:     private fun fire(event: LifecycleEvent, timing: LifecycleTiming, info: LifecycleInfo, forwarded: Boolean = false) {
```

## Android/core/src/main/kotlin/com/chenyilong/cyldeallocblockexecutor/Types.kt (77 lines)
```
4: enum class LifecycleEvent {
37: enum class LifecycleTiming { beforeSuper, afterSuper, end }
39: data class Insets(val top: Int = 0, val left: Int = 0, val bottom: Int = 0, val right: Int = 0)
41: data class Size(val width: Int, val height: Int)
44: data class ConfigSnapshot(val size: Size, val nightMode: Boolean?, val fontScale: Float)
47: data class LifecycleInfo(
48:     val event: LifecycleEvent? = null,
49:     val timing: LifecycleTiming = LifecycleTiming.afterSuper,
50:     val animated: Boolean = false,
52:     val size: Size? = null,
54:     val previousNightMode: Boolean? = null,
55:     val previousFontScale: Float? = null,
57:     val previousInsets: Insets? = null,
59:     val parentAttached: Boolean? = null,
61:     val trimLevel: Int? = null,
63:     val isDealloc: Boolean = false,
65:     val scrollView: Any? = null,
67:     val willDecelerate: Boolean? = null,
69:     val window: Any? = null,
71:     val customEvent: String? = null,
73:     val userInfo: Map<String, Any?>? = null,
77: typealias LifecycleCallback<T> = (owner: T, identifier: Int, info: LifecycleInfo) -> Unit
```

## Flutter/lib/cyl_dealloc_block_executor.dart (9 lines)
```
5: export 'src/lifecycle_center.dart';
6: export 'src/lifecycle_event.dart';
7: export 'src/lifecycle_log.dart';
8: export 'src/lifecycle_mixin.dart';
9: export 'src/lifecycle_registry.dart';
```

## Flutter/lib/src/lifecycle_center.dart (184 lines)
```
4: class _GlobalEntry {
20:   final bool Function(Object owner)? ownerType;
32: class LifecycleCenter {
36:   static int _nextIdentifier = 1;
40:   static bool get isUserScrolling {
45:   static int addCallback<T extends Object>(
61:   static int addCustomCallback<T extends Object>(
75:   static int _add(_GlobalEntry prototype) {
97:   static void Function() whileUserScrolls(
112:   static bool cancelCallback({int? identifier, String? key}) {
127:   static int addDeallocObserver(
136:   static bool cancelDeallocObserver({int? identifier, String? key}) {
146:   static void dispatchDealloc(String description) {
156:   static void reset() {
163:   static void dispatch(Object owner, LifecycleEvent? event, String? custom,
```

## Flutter/lib/src/lifecycle_event.dart (122 lines)
```
8: enum LifecycleEvent {
41: enum LifecycleTiming { beforeSuper, afterSuper, end }
44: class LifecycleInfo {
121: typedef LifecycleCallback<T extends Object> = void Function(
```

## Flutter/lib/src/lifecycle_log.dart (41 lines)
```
10: class LifecycleLog {
13:   static bool enabled = false;
14:   static void Function(String message) sink = print;
17:   static String Function(Object? owner) describer = (owner) =>
20:   static String describe(Object? owner) => describer(owner);
22:   static void log(String Function() message) {
28: abstract final class AnimationEvents {
35: abstract final class BadgeEvents {
```

## Flutter/lib/src/lifecycle_mixin.dart (447 lines)
```
39: mixin CYLLifecycleMixin<W extends StatefulWidget> on State<W> {
49:   final List<VoidCallback> _animationDetach = [];
50:   bool _appearPending = false;
51:   bool _disappearPending = false;
52:   bool _disposed = false;
53:   bool _removing = false;
54:   bool _onScreen = false;
55:   bool _dragging = false;
56:   bool _decelerating = false;
73:   bool get observerAttached => _binding != null;
75:   void _onRegister(LifecycleEvent event) {
81:   void _attachBinding() {
95:   FlutterView? get _view {
100:   static EdgeInsets _padding(FlutterView view) => EdgeInsets.fromViewPadding(
105:   void _around(LifecycleEvent event, LifecycleInfo info, void Function() call) {
113:   void _moveToParent(bool attached, void Function() call) {
121:   void initState() {
132:   void didChangeDependencies() {
145:   void activate() {
150:   void deactivate() {
155:   void dispose() {
179:   bool get _animated =>
182:   void _willAppear() {
190:   void _willDisappear() {
195:   void _fireEvent(LifecycleEvent event, {LifecycleInfo? info}) {
204:   void _didAppear() {
211:   void _didDisappear() {
218:   void _flushPending() {
225:   void _await(Animation<double>? animation, AnimationStatus target,
244:   void _detachRoute() {
263:   void setScreenVisible(bool visible) {
273:   Widget scrollLifecycle({required Widget child}) =>
282:   void _onScrollNotification(ScrollNotification n) {
326:   Widget layoutLifecycle({required Widget child}) =>
330: class _RouteListener with RouteAware {
335:   void didPush() {
342:   void didPopNext() {
349:   void didPushNext() {
356:   void didPop() {
363: class _BindingObserver with WidgetsBindingObserver {
368:   void didChangeMetrics() {
391:   void _trait() {
405:   void didChangePlatformBrightness() => _trait();
408:   void didChangeTextScaleFactor() => _trait();
411:   void didHaveMemoryPressure() => _state._fireEvent(
415: class _LayoutLifecycle extends SingleChildRenderObjectWidget {
424:   void updateRenderObject(
430: class _RenderLayoutLifecycle extends RenderProxyBox {
434:   void _fire(LifecycleEvent event) {
442:   void performLayout() {
```

## Flutter/lib/src/lifecycle_registry.dart (406 lines)
```
7: class _Entry {
25:   bool fired = false;
26:   bool cancelled = false;
28:   bool get isDealloc => event == null && custom == null;
42: class LifecycleRegistry {
43:   LifecycleRegistry(Object owner) : _owner = WeakReference<Object>(owner);
49:   static LifecycleRegistry of(Object owner) =>
53:   final List<_Entry> _entries = [];
54:   int _nextIdentifier = 1;
58:   final List<(WeakReference<LifecycleRegistry>, Set<LifecycleEvent>?)> _forwards = [];
62:   void Function(LifecycleEvent event)? onRegister;
65:   bool hookInstalled = false;
67:   int get blockCount => _entries.where((e) => !e.cancelled).length;
69:   int _add(_Entry entry) {
74:   void _removeKey(String? key, {required bool dealloc, bool custom = false}) {
90:   int addLifecycleCallback<T extends Object>(
115:   int addCustomCallback<T extends Object>(
135:   void postLifecycleEvent(String name, {Map<String, Object?>? userInfo}) =>
141:   void _post(String name, Map<String, Object?>? userInfo,
177:   void forwardLifecycleEvents(LifecycleRegistry target,
186:   List<LifecycleRegistry> _liveForwards(LifecycleEvent? event) {
197:   bool cancelLifecycleCallback({int? identifier, String? key}) =>
201:   void cancelAllLifecycleCallbacks(LifecycleEvent event,
216:   void rearmLifecycleCallbacks(LifecycleEvent event,
229:   void rearmLifecycleCallback({required String key}) {
238:   int addDeallocCallback<T extends Object>(
252:   bool cancelDeallocCallback({int? identifier, String? key}) =>
256:   void cancelAllDeallocCallbacks() {
263:   bool _cancelOne({int? identifier, String? key, required bool dealloc}) {
280:   void runDealloc() {
303:   void setManualLifecycleDispatch(bool manual, Set<LifecycleEvent> events,
316:   bool isManual(LifecycleEvent event, LifecycleTiming timing) =>
321:   bool isAutomatic(LifecycleEvent event, LifecycleTiming timing) =>
326:   void fireAutomatic(LifecycleEvent event, LifecycleTiming timing,
334:   void invokeLifecycleCallbacks(
348:   void performLifecycle(
377:   void _fire(LifecycleEvent event, LifecycleTiming timing, LifecycleInfo info,
```

## HarmonyOS/cyldeallocblockexecutor/Index.ets (8 lines)
```
1: export { LifecycleController } from './src/main/ets/controller';
2: export type { Rect } from './src/main/ets/controller';
3: export { LifecycleRegistry } from './src/main/ets/registry';
4: export { LifecycleCenter } from './src/main/ets/center';
5: export { LifecycleLog, AnimationEvents, BadgeEvents } from './src/main/ets/log';
6: export { LifecycleEvent, LifecycleTiming, allTimings } from './src/main/ets/types';
7: export type { Insets, LifecycleCallback, LifecycleInfo } from './src/main/ets/types';
8: export { CYLLifecycleBridge } from './src/main/ets/CYLLifecycleBridge';
```

## HarmonyOS/cyldeallocblockexecutor/src/main/ets/CYLLifecycleBridge.ets (112 lines)
```
25: export class CYLLifecycleBridge<T extends Object> {
31:   constructor(owner: T) {
40:   aboutToAppear(initialColorMode?: number): void {
45:   onPageShow(): void {
49:   onPageHide(): void {
54:   onAreaChange(oldArea: Rect, area: Rect): void {
59:   onMemoryLevel(level: number): void {
64:   onConfigurationUpdate(colorMode: number): void {
71:   attachWindow(win: window.Window): void {
97:   private detachWindow(): void {
108:   aboutToDisappear(): void {
```

## HarmonyOS/cyldeallocblockexecutor/src/main/ets/center.ts (147 lines)
```
15: export interface KeyOptions {
19: export interface CenterOptions {
33: export class LifecycleCenter {
39:   static get isUserScrolling(): boolean {
46:   static addCallback<T = any>(event: LifecycleEvent, callback: LifecycleCallback<T>, options: CenterOptions = {}): number {
50:   static addCustomCallback<T = any>(name: string, callback: LifecycleCallback<T>, options: CenterOptions = {}): number {
54:   private static add(event: LifecycleEvent | null, custom: string | undefined, callback: LifecycleCallback<any>, options: CenterOptions): number {
85:   static cancelCallback(target: { identifier: number } | { key: string }): boolean {
99:   static addDeallocObserver(callback: (description: string, info: LifecycleInfo) => void, options: KeyOptions = {}): number {
106:   static cancelDeallocObserver(target: { identifier: number } | { key: string }): boolean {
115:   static dispatchDealloc(description: string): void {
122:   static reset(): void {
129:   static dispatch(owner: object, event: LifecycleEvent | null, custom: string | undefined, timing: LifecycleTiming, info: LifecycleInfo): void {
```

## HarmonyOS/cyldeallocblockexecutor/src/main/ets/controller.ts (165 lines)
```
4: export interface Rect {
35: export class LifecycleController<T extends object> {
46:   constructor(owner: T) {
53:   get isDetached(): boolean {
57:   private around(event: LifecycleEvent, info: Partial<LifecycleInfo> = {}): void {
63:   windowAttached(window?: unknown): void {
69:   windowDetached(): void {
76:   visibleAreaChanged(visible: boolean): void {
81:   setScreenVisible(visible: boolean): void {
88:   scrollStarted(scrollView?: unknown): void {
93:   scrollStopped(scrollView?: unknown): void {
99:   aboutToAppear(): void {
108:   onPageShow(): void {
118:   onPageHide(): void {
127:   aboutToDisappear(): void {
137:   onAreaChange(_old: Rect, area: Rect): void {
146:   avoidAreaChanged(insets: Insets): void {
154:   colorModeChanged(mode: string): void {
162:   memoryLevel(level: number, criticalLevel = 2): void {
```

## HarmonyOS/cyldeallocblockexecutor/src/main/ets/index.ts (10 lines)
```
1: export { LifecycleRegistry } from './registry';
2: export { LifecycleCenter } from './center';
3: export { LifecycleLog, AnimationEvents, BadgeEvents } from './log';
4: export type { LogSink } from './log';
5: export type { CenterOptions, KeyOptions } from './center';
6: export type { AddOptions, CustomOptions, DeallocOptions } from './registry';
7: export { LifecycleEvent, LifecycleTiming, allTimings } from './types';
8: export type { Insets, LifecycleCallback, LifecycleInfo } from './types';
9: export { LifecycleController } from './controller';
10: export type { Rect } from './controller';
```

## HarmonyOS/cyldeallocblockexecutor/src/main/ets/log.ts (42 lines)
```
1: export type LogSink = (message: string) => void;
10: export class LifecycleLog {
14:   static log(message: () => string): void {
19:   static describe(owner: unknown): string {
29: export const AnimationEvents = {
36: export const BadgeEvents = {
```

## HarmonyOS/cyldeallocblockexecutor/src/main/ets/registry.ts (354 lines)
```
22: export interface CustomOptions {
28: export interface DeallocOptions {
32: export interface AddOptions {
50: export class LifecycleRegistry {
52:   static of(owner: object): LifecycleRegistry {
74:   constructor(owner: object) {
78:   hasBlocksFor(event: LifecycleEvent): boolean {
82:   get blockCount(): number {
87:   private drop(match: (e: Entry) => boolean): void {
92:   private removeKey(key: string | undefined, kind: Kind): void {
100:   addLifecycleCallback<T = any>(
123:   cancelLifecycleCallback(target: { identifier: number } | { key: string }): boolean {
130:   addCustomCallback<T = any>(name: string, callback: LifecycleCallback<T>, options: CustomOptions = {}): number {
148:   postLifecycleEvent(name: string, userInfo?: Record<string, unknown>): void {
156:   private post(name: string, userInfo: Record<string, unknown> | undefined, forwarded: boolean): void {
180:   forwardLifecycleEvents(target: LifecycleRegistry, events?: readonly LifecycleEvent[]): void {
188:   private liveForwards(event: LifecycleEvent | undefined): LifecycleRegistry[] {
199:   cancelAllLifecycleCallbacks(event: LifecycleEvent, timing?: LifecycleTiming): void {
204:   rearmLifecycleCallbacks(event: LifecycleEvent, timing?: LifecycleTiming): void {
213:   rearmLifecycleCallback(key: string): void {
222:   addDeallocCallback<T = any>(callback: LifecycleCallback<T>, options: DeallocOptions = {}): number {
239:   cancelDeallocCallback(target: { identifier: number } | { key: string }): boolean {
244:   cancelAllDeallocCallbacks(): void {
248:   private cancelOne(target: { identifier: number } | { key: string }, dealloc: boolean): boolean {
261:   runDealloc(): void {
277:   setManualLifecycleDispatch(
290:   isManual(event: LifecycleEvent, timing: LifecycleTiming): boolean {
295:   isAutomatic(event: LifecycleEvent, timing: LifecycleTiming): boolean {
300:   fireAutomatic(event: LifecycleEvent, timing: LifecycleTiming, info: Partial<LifecycleInfo> = {}): void {
306:   invokeLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming, info: Partial<LifecycleInfo> = {}): void {
320:   performLifecycle(
338:   private fire(event: LifecycleEvent, timing: LifecycleTiming, info: Partial<LifecycleInfo>, forwarded = false): void {
```

## HarmonyOS/cyldeallocblockexecutor/src/main/ets/types.ts (84 lines)
```
5: export const LifecycleEvent = {
30: export type LifecycleEvent = (typeof LifecycleEvent)[keyof typeof LifecycleEvent];
38: export const LifecycleTiming = {
43: export type LifecycleTiming = (typeof LifecycleTiming)[keyof typeof LifecycleTiming];
45: export const allTimings: readonly LifecycleTiming[] = ['beforeSuper', 'afterSuper', 'end'];
47: export interface Insets {
55: export interface LifecycleInfo {
84: export type LifecycleCallback<T> = (owner: T, identifier: number, info: LifecycleInfo) => void;
```

## ReactNative/src/center.ts (147 lines)
```
15: export interface KeyOptions {
19: export interface CenterOptions {
33: export class LifecycleCenter {
39:   static get isUserScrolling(): boolean {
46:   static addCallback<T = any>(event: LifecycleEvent, callback: LifecycleCallback<T>, options: CenterOptions = {}): number {
50:   static addCustomCallback<T = any>(name: string, callback: LifecycleCallback<T>, options: CenterOptions = {}): number {
54:   private static add(event: LifecycleEvent | null, custom: string | undefined, callback: LifecycleCallback<any>, options: CenterOptions): number {
85:   static cancelCallback(target: { identifier: number } | { key: string }): boolean {
99:   static addDeallocObserver(callback: (description: string, info: LifecycleInfo) => void, options: KeyOptions = {}): number {
106:   static cancelDeallocObserver(target: { identifier: number } | { key: string }): boolean {
115:   static dispatchDealloc(description: string): void {
122:   static reset(): void {
129:   static dispatch(owner: object, event: LifecycleEvent | null, custom: string | undefined, timing: LifecycleTiming, info: LifecycleInfo): void {
```

## ReactNative/src/controller.ts (364 lines)
```
5: export const MEMORY_WARNING_EVENT = 'cylMemoryWarning';
15: export interface PlatformSources {
77: export interface ControllerOptions {
89: export class LifecycleController<T extends object> {
108:   constructor(owner: T, sources: PlatformSources = {}, options: ControllerOptions = {}) {
117:   private around(event: LifecycleEvent, info: Partial<LifecycleInfo> = {}, call?: () => void): void {
124:   attach(): void {
134:   detach(): void {
155:   setScreenVisible(visible: boolean): void {
190:   private flushPending(): void {
197:   private willAppear(): void {
204:   private isAppearing(): void {
211:   private didAppear(): void {
219:   private willDisappear(): void {
226:   private didDisappear(): void {
248:   private subscribeAll(): void {
254:   private subscribeFor(event: LifecycleEvent): void {
295:   private subscribeNavigation(nav: NonNullable<PlatformSources['navigation']>): void {
323:   private insetsChanged(insets: Insets): void {
343:   private colorSchemeChanged(colorScheme: string | null | undefined): void {
356: export function mountLifecycle<T extends object>(
```

## ReactNative/src/index.ts (9 lines)
```
1: export * from './types.ts';
2: export { LifecycleRegistry } from './registry.ts';
3: export { LifecycleCenter } from './center.ts';
4: export { LifecycleLog, AnimationEvents, BadgeEvents } from './log.ts';
5: export type { LogSink } from './log.ts';
6: export type { CenterOptions, KeyOptions } from './center.ts';
7: export type { AddOptions, CustomOptions, DeallocOptions } from './registry.ts';
8: export { LifecycleController, mountLifecycle, MEMORY_WARNING_EVENT } from './controller.ts';
9: export type { ControllerOptions, PlatformSources } from './controller.ts';
```

## ReactNative/src/log.ts (42 lines)
```
1: export type LogSink = (message: string) => void;
10: export class LifecycleLog {
14:   static log(message: () => string): void {
19:   static describe(owner: unknown): string {
29: export const AnimationEvents = {
36: export const BadgeEvents = {
```

## ReactNative/src/native.ts (60 lines)
```
11: export function createNativeSources(extra: {
33: export function useLifecycle<T extends object>(
```

## ReactNative/src/registry.ts (354 lines)
```
22: export interface CustomOptions {
28: export interface DeallocOptions {
32: export interface AddOptions {
50: export class LifecycleRegistry {
52:   static of(owner: object): LifecycleRegistry {
74:   constructor(owner: object) {
78:   hasBlocksFor(event: LifecycleEvent): boolean {
82:   get blockCount(): number {
87:   private drop(match: (e: Entry) => boolean): void {
92:   private removeKey(key: string | undefined, kind: Kind): void {
100:   addLifecycleCallback<T = any>(
123:   cancelLifecycleCallback(target: { identifier: number } | { key: string }): boolean {
130:   addCustomCallback<T = any>(name: string, callback: LifecycleCallback<T>, options: CustomOptions = {}): number {
148:   postLifecycleEvent(name: string, userInfo?: Record<string, unknown>): void {
156:   private post(name: string, userInfo: Record<string, unknown> | undefined, forwarded: boolean): void {
180:   forwardLifecycleEvents(target: LifecycleRegistry, events?: readonly LifecycleEvent[]): void {
188:   private liveForwards(event: LifecycleEvent | undefined): LifecycleRegistry[] {
199:   cancelAllLifecycleCallbacks(event: LifecycleEvent, timing?: LifecycleTiming): void {
204:   rearmLifecycleCallbacks(event: LifecycleEvent, timing?: LifecycleTiming): void {
213:   rearmLifecycleCallback(key: string): void {
222:   addDeallocCallback<T = any>(callback: LifecycleCallback<T>, options: DeallocOptions = {}): number {
239:   cancelDeallocCallback(target: { identifier: number } | { key: string }): boolean {
244:   cancelAllDeallocCallbacks(): void {
248:   private cancelOne(target: { identifier: number } | { key: string }, dealloc: boolean): boolean {
261:   runDealloc(): void {
277:   setManualLifecycleDispatch(
290:   isManual(event: LifecycleEvent, timing: LifecycleTiming): boolean {
295:   isAutomatic(event: LifecycleEvent, timing: LifecycleTiming): boolean {
300:   fireAutomatic(event: LifecycleEvent, timing: LifecycleTiming, info: Partial<LifecycleInfo> = {}): void {
306:   invokeLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming, info: Partial<LifecycleInfo> = {}): void {
320:   performLifecycle(
338:   private fire(event: LifecycleEvent, timing: LifecycleTiming, info: Partial<LifecycleInfo>, forwarded = false): void {
```

## ReactNative/src/types.ts (84 lines)
```
5: export const LifecycleEvent = {
30: export type LifecycleEvent = (typeof LifecycleEvent)[keyof typeof LifecycleEvent];
38: export const LifecycleTiming = {
43: export type LifecycleTiming = (typeof LifecycleTiming)[keyof typeof LifecycleTiming];
45: export const allTimings: readonly LifecycleTiming[] = ['beforeSuper', 'afterSuper', 'end'];
47: export interface Insets {
55: export interface LifecycleInfo {
84: export type LifecycleCallback<T> = (owner: T, identifier: number, info: LifecycleInfo) => void;
```

## MiniProgram/center.js (133 lines)
```
13: const cylWeakRef = (o) => (typeof WeakRef === 'function' ? new WeakRef(o) : { deref: () => o });
15: class LifecycleCenter {
18:   static get isUserScrolling()          {
25:   static addCallback         (event                , callback                      , options                = {})         {
29:   static addCustomCallback         (name        , callback                      , options                = {})         {
33:           static add(event                       , custom                    , callback                        , options               )         {
53:   static whileUserScrolls(pause            , resume            , options             = {})             {
64:   static cancelCallback(target                                          )          {
77:   static addDeallocObserver(callback                                                    , options             = {})         {
84:   static cancelDeallocObserver(target                                          )          {
93:   static dispatchDealloc(description        )       {
100:   static reset()       {
107:   static dispatch(owner        , event                       , custom                    , timing                 , info               )       {
133: module.exports = { LifecycleCenter };
```

## MiniProgram/controller.js (185 lines)
```
23: class LifecycleController {
24:   constructor(owner) {
40:   get isDetached() {
44:   around(event, info = {}) {
49:   onLoad() {
59:   onShow() {
70:   onReady() {
79:   onHide() {
87:   onUnload() {
100:   screenVisible(visible) {
111:   observeScreen(selector, options = {}, api = typeof wx !== 'undefined' ? wx : undefined) {
119:   onPageScroll(event) {
129:   endScrolling(event) {
136:   onResize(size) {
142:   themeChanged(theme) {
149:   memoryWarning() {
159: function withLifecycle(options) {
185: module.exports = { LifecycleController, withLifecycle };
```

## MiniProgram/index.js (9 lines)
```
3: const registry = require('./registry');
4: const center = require('./center');
5: const log = require('./log');
6: const types = require('./types');
7: const controller = require('./controller');
9: module.exports = Object.assign({}, registry, center, log, types, controller);
```

## MiniProgram/log.js (45 lines)
```
8: class LifecycleLog {
10:   static log(message              )       {
15:   static describe(owner         )         {
30: const AnimationEvents = {
37: const BadgeEvents = {
45: module.exports = { LifecycleLog, AnimationEvents, BadgeEvents };
```

## MiniProgram/registry.js (331 lines)
```
4: const cylWeakRef = (o) => (typeof WeakRef === 'function' ? new WeakRef(o) : { deref: () => o });
6: const kindOf = (e       )       => (e.event !== null ? 'lifecycle' : e.custom !== undefined ? 'custom' : 'dealloc');
12: const registries = new WeakMap();
24: class LifecycleRegistry {
26:   static of(owner        )                    {
40:   constructor(owner        ) {
53:   hasBlocksFor(event                )          {
57:   get blockCount()         {
62:           drop(match                       )       {
67:           removeKey(key                    , kind      )       {
75:   addLifecycleCallback         (
98:   cancelLifecycleCallback(target                                          )          {
105:   addCustomCallback         (name        , callback                      , options                = {})         {
123:   postLifecycleEvent(name        , userInfo                          )       {
131:           post(name        , userInfo                                     , forwarded         )       {
155:   forwardLifecycleEvents(target                   , events                            )       {
163:           liveForwards(event                            )                      {
174:   cancelAllLifecycleCallbacks(event                , timing                  )       {
179:   rearmLifecycleCallbacks(event                , timing                  )       {
188:   rearmLifecycleCallback(key        )       {
197:   addDeallocCallback         (callback                      , options                 = {})         {
214:   cancelDeallocCallback(target                                          )          {
219:   cancelAllDeallocCallbacks()       {
223:           cancelOne(target                                          , dealloc         )          {
236:   runDealloc()       {
252:   setManualLifecycleDispatch(
265:   isManual(event                , timing                 )          {
270:   isAutomatic(event                , timing                 )          {
275:   fireAutomatic(event                , timing                 , info                         = {})       {
281:   invokeLifecycleCallbacks(event                , timing                 , info                         = {})       {
295:   performLifecycle(
313:           fire(event                , timing                 , info                        , forwarded = false)       {
331: module.exports = { LifecycleRegistry };
```

## MiniProgram/types.js (49 lines)
```
5: const LifecycleEvent = {
37: const LifecycleTiming = {
49: module.exports = { LifecycleEvent, LifecycleTiming, allTimings };
```
