# Lifecycle callbacks

This document tracks the lifecycle block API of CYLDeallocBlockExecutor: blocks run at UIKit lifecycle events of an object, in the same way as the dealloc block. The API will become a core dependency of [CYLTabBarController](https://github.com/ChenYilong/CYLTabBarController), which will use it for its layout block and its theme (skin) interfaces, as the README describes for the dealloc block.

## Task log

### DONE: CI checks (2026-11-22, branch `feat/lifecycle-callbacks`, PR #12)

**Context.** The repository has no CI. Every check in this document (lifecycle tests, `pod lib lint`, SPM build, Example build) ran only on the local Mac.

**Requirement (English translation of the prompt).** Add CI checks.

**Prompt (verbatim).** 添加ci 检查擦

**Result.** `.github/workflows/ci.yml`, run [44955521212](https://github.com/ChenYilong/CYLDeallocBlockExecutor/actions/runs/44955521212) on PR #12: all 5 jobs pass on `macos-26` (macOS 26.7.2, Xcode 26.6 17F113). shellcheck; Swift package build with warnings as errors; Example build (only the old asset catalog warnings); `pod lib lint` (`passed validation`); lifecycle tests on an iPhone 16e simulator: `RESULT: PASS 38 passed, 0 failed` in both swizzle orders, in Debug and in Release. The README has a CI badge, and its platform badge now says iOS 15.0+. Pushing a workflow file needs the `workflow` scope: the HTTPS (gh OAuth) push was rejected, the SSH push worked.

**Plan.** One GitHub Actions workflow on GitHub-hosted runners (`macos-26`, as CYLTabBarController uses): shellcheck, SPM build, Example build, `pod lib lint`, and the lifecycle tests on a new simulator in Debug and Release.

### DONE: lifecycle blocks for CYLTabBarController (2026-11-22, branch `feat/lifecycle-callbacks`, PR #12)

**Result.** Score 100 (29 / 29 after the re-check round). Evidence: `bash Tests/run-lifecycle-tests.sh <simulator UDID>` on iOS 27.2 (iPhone 18 Pro simulator, macOS 27.3, Xcode 27.2 27B52): `RESULT: PASS 31 passed, 0 failed` in both runs (38 after the re-check round) (exchange swizzle installed after and before the hooks), in Debug and Release on iOS 27.2 and in Debug on iOS 17.5 (iPhone 15 simulator; the iOS 15.0 runtime does not run on macOS 27). `pod lib lint` (full build) passes. Example builds clean into a fresh derived data folder (only the old asset catalog warnings remain, see the prerequisites table).

**Context.** The library only offers a dealloc block (`cyl_willDealloc(selfCallback:)`). CYLTabBarController has its own one-off layout block (`viewDidLayoutSubviewsBlock`, `invokeOnceViewDidLayoutSubViewsBlock`, `-cyl_rearmViewDidLayoutSubviewsBlockInvokeOnce`) and wants to replace such code with this library.

**Requirements (English translation of the prompt).**

- Add blocks for more iOS lifecycle events, modeled on UIKit's `UIViewController` lifecycle. The library will become a core dependency of CYLTabBarController, which will use the dealloc block for its theme (skin) APIs, as the README says.
- Extend the `invokeOnceViewDidLayoutSubViewsBlock` pattern: like the dealloc definition, each block gets an identifier and an owner.
- CYLTabBarController must be able to call this library directly to keep its existing behavior. Align the dealloc block's parameters with the same design.
- Swift only.
- Like dealloc, each lifecycle event accepts several blocks per object, guarded by the lock the dealloc API uses.
- Create `docs/`, add this TODO and a table, in English: column 1 the lifecycle method to implement, column 2 its description, column 3 the API or implementation (`TODO` by default).
- Scoring: no `TODO` in column 3 = 100, all `TODO` = 0.
- Loop: (1) search the existing code for each TODO, (2) score, (3) implement the TODOs one by one and fill in column 3, (4) score; repeat until 100.

**Follow-up (2026-11-22, verbatim):**

> 生命周期可能和dealloc 也不太一样， 生命周期可能还可以在顶部执行， 顶部与底部的区分， 可以参数控制， 顶部可能也需要区分是在 super方法调用前还是调用后， 也可以通过参数控制。 请使用advisor评估如何设计。 接口设计都需要使用advisor来设计

**English:** Lifecycle blocks differ from dealloc: they may also run at the top of a method. Top versus bottom is chosen by a parameter, and the top also distinguishes before and after the `super` call, again by a parameter. Use the advisor to evaluate the design; every interface design goes through the advisor.

**Follow-up 2 (2026-11-22, verbatim):**

> advisor 在接口实现过程中充分参考CYLTabBarController 里的生命周期需求， 已帮助其将来集成进core代码中， 能实现用户集成后， 以及core核心代码在实现过程中更加低耦合的加入生命周期管理。也需要参考本项目readme相关描述， 参考其便利性

**English:** While implementing the interface, the advisor must fully consider CYLTabBarController's lifecycle needs, so the library can later be integrated into its core, letting both the app (after integration) and the core add lifecycle management with low coupling. Also follow this project's README and keep its convenience.


**Re-check request (2026-11-22, verbatim, re-sent with the original prompt):**

> advisor 在接口实现过程中充分参考CYLTabBarController 里的生命周期需求， 已帮助其将来集成进core代码中， 能实现用户集成后， 以及core核心代码在实现过程中更加低耦合的加入生命周期管理。也需要参考本项目readme相关描述， 参考其便利性 .  - Other session's request: the CYLTabBarController session asked me to take

**English:** Re-check that the interface fully follows CYLTabBarController's lifecycle needs (future core integration, low coupling for the app and the core) and the README's convenience. The message also quotes, cut off, the report line about the CYLTabBarController session's request.

<details>
<summary>Original prompt (verbatim)</summary>

增加更多iOS生命周期的触发block， 将来会集成进CYLTabBarController 的core核心依赖中，详细阅读readme文件， 将来会将dealloc的block用于换肤相关的接口， 正如readme所言。 更多生命周期，参考 

```swift
private var invokeOnceViewDidLayoutSubViewsBlockStorage = false
    /// [EN] Getter `shouldInvokeOnce…`, setter `setInvokeOnce…:` (the selectors the Objective-C property had). [CN] getter 为 `shouldInvokeOnce…`、setter 为 `setInvokeOnce…:`（与原 Objective-C 属性的 selector 相同）。
    @objc(shouldInvokeOnceViewDidLayoutSubViewsBlock) var invokeOnceViewDidLayoutSubViewsBlock: Bool {
        @objc(shouldInvokeOnceViewDidLayoutSubViewsBlock) get { invokeOnceViewDidLayoutSubViewsBlockStorage }
        @objc(setInvokeOnceViewDidLayoutSubViewsBlock:) set { invokeOnceViewDidLayoutSubViewsBlockStorage = newValue }
    }
```

 ， 不过该接口需要扩展， 模仿 dealloc的定义增加id以及owner回调， 更多生命周期， 可以参考UIKit中UIViewController的生命周期，要求CYLTabBarController 可以直接调用该库来完成原有功能。 结合 CYLTabBarController 中的参考方法， 为dealloc 也对齐参数。 全Swift 实现。 新增生命周期方法， 要求和dealloc 方法一样能增加多个block并使用dealloc所使用的锁， 一个一个对象增加多个生命周期block执行。 新建docs 文件夹， 先增加todo，以及生命周期待实现的找到下面描述中相关的文档，如果没有就新建，如果有就插入：全英文写入：制作一个表格，第一列为待实现的生命周期方法 ，第二列为功能描述，第三列为 对应的api或者功能。第三列默认为TODO。制作评分系统，第三列没有TODO 为满分，全部是TODO为0分。制作表格以及评分系统完成后，第一步 尝试搜索现有代码，尝试匹配TODO项，寻找对应的api和功能。第二：打分。第三：。开始逐一处理TODO。并更新TODO为对应实现。第四步骤：打分。如此循环往复一直到满分为止。

Follow-up message (second reference from CYLTabBarController):

```swift
/// [EN] The block run at the end of `-viewDidLayoutSubviews`. [CN] 在 `-viewDidLayoutSubviews` 末尾执行的 block。
public typealias CYLViewDidLayoutSubViewsBlock = (CYLTabBarController) -> Void
```

</details>

## Design (reviewed by the advisor, 2026-11-22)

Every public interface below was designed with the advisor; any new public API goes back to the advisor first.

### Timing

The reference point is the `super` call that reaches UIKit's implementation, not the first line of an override.

| Timing | Fires | Automatic dispatch | Manual dispatch |
| :-- | :-- | :-- | :-- |
| `.beforeSuper` | Right before UIKit's implementation runs (top, before `super`) | Yes, every view controller | Yes |
| `.afterSuper` (default) | Right after UIKit's implementation returns (top, after `super`) | Yes, every view controller | Yes |
| `.end` | After the owner's override body (bottom) | Only when the class does not override the method (then right after `.afterSuper`); otherwise a debug log asks for manual dispatch | Yes |

### API

```swift
public enum CYLLifecycleEvent: Int    // viewDidLoad … didReceiveMemoryWarning (no dealloc case)
public enum CYLLifecycleTiming: Int   // beforeSuper, afterSuper, end
public struct CYLLifecycleInfo        // event, timing, animated, size, previousTraitCollection, parent

// Typed owner (Self), like CYLViewDidLayoutSubViewsBlock = (CYLTabBarController) -> Void
@discardableResult
func cyl_addLifecycleCallback(for: CYLLifecycleEvent, timing: CYLLifecycleTiming = .afterSuper, invokeOnce: Bool = false,
                              callback: @escaping (_ owner: Self, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void) -> UInt
func cyl_cancelLifecycleCallback(identifier: UInt) -> Bool
func cyl_cancelAllLifecycleCallbacks(for: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil)
func cyl_rearmLifecycleCallbacks(for: CYLLifecycleEvent, timing: CYLLifecycleTiming? = nil)

// Manual dispatch
func cyl_performLifecycle(_ event: CYLLifecycleEvent, info: CYLLifecycleInfo, callSuper: () -> Void, body: () -> Void)
func cyl_setManualLifecycleDispatch(_ manual: Bool, for events: Set<CYLLifecycleEvent>)
func cyl_invokeLifecycleCallbacks(for: CYLLifecycleEvent, timing: CYLLifecycleTiming, info: CYLLifecycleInfo)

// Dealloc aligned with the same shape (the 1.3.0 API stays unchanged)
func cyl_willDealloc(callback: @escaping (_ owner: Unmanaged<AnyObject>, _ identifier: UInt, _ info: CYLLifecycleInfo) -> Void) -> UInt
```

### Rules

- One model per object holds the dealloc blocks and the lifecycle blocks; one identifier counter for all of them, so cancelling by identifier is never ambiguous.
- The model is created under `deallocCallbackLock`, as the dealloc model always was; adding, cancelling, re-arming and collecting the blocks to run happen under the model's lock. Blocks run after the lock is released, in identifier order, so a block can add or cancel blocks.
- Invoke-once entries keep a `fired` flag: firing skips fired entries, re-arming clears the flag. Re-arming never touches the view (no `setNeedsLayout`).
- Dealloc stays out of the typed generic API: a typed owner would be retained while it is being destroyed. The dealloc owner stays `Unmanaged`.
- Automatic hooks: `method_setImplementation` on `UIViewController` with the previous implementation captured (no exchange with a named selector, so other swizzles such as CYLTabBarController's keep working), installed lazily the first time a lifecycle block is added. `viewIsAppearing:` is hooked only when `class_getInstanceMethod` finds it; `traitCollectionDidChange:` is reached by `NSSelectorFromString` (deprecated in iOS 17, no warning).
- No double firing: while `cyl_performLifecycle` runs an event for an object, the automatic hook skips that object and event. The raw `cyl_invokeLifecycleCallbacks` requires the event to be declared manual first (debug assertion otherwise).
- Callers use the `owner` parameter instead of capturing `self`: a block stored on `self` that captures `self` strongly is a retain cycle.

### Design v2: CYLTabBarController's needs (advisor, 2026-11-22)

CYLTabBarController's overrides today call `super` first and then a `cyl…()` body (`viewWillAppear`, `viewDidAppear`, `viewWillDisappear`, `viewDidDisappear`, `viewWillLayoutSubviews`, `viewDidLayoutSubviews`, `traitCollectionDidChange`, `didReceiveMemoryWarning`); `viewWillTransition` does its work before `super`; `deinit` removes KVO observers that were added only under some conditions (the README's flag problem). v2 changes:

1. **The core registers `.afterSuper` / `.beforeSuper`, never `.end`.** The hook lives on `UIViewController`, so an app subclass of the (open) core class still reaches it through `super`: app code before `super` → `.beforeSuper` → UIKit → `.afterSuper` (the core) → app code after `super`, the order of today's `super` + `cyl…()`. `.end` fires automatically only for classes that do not override the method, which an app subclass would silently break.
2. **Manual dispatch per (event, timing).** `cyl_setManualLifecycleDispatch(_:for:timings:)` (all timings by default): CYLTabBarController keeps `.afterSuper` of `viewDidLayoutSubviews` automatic and dispatches `.end` (the app's layout block) itself.
3. **Replace by key.** `cyl_addLifecycleCallback(…, key:)` and `cyl_willDealloc(key:callback:)` remove the block added before under the same key in the same locked step; the new block starts unfired (replacing re-arms). The layout-block setter, a twice-called install method and the README's `themeMap` setter keep one block each. No priority parameter: registration order runs the core (init) before the app.
4. **Dealloc capture rule.** When a dealloc block runs, UIKit's ivars (`tabBar`) may already be released: capture the observed object strongly where the observer is added, never read it through `owner`; `NotificationCenter.default.removeObserver(owner.takeUnretainedValue())` only uses the address and stays fine.

| CYLTabBarController today | With this library (v2) |
| :-- | :-- |
| `viewWillAppear` … `viewDidDisappear`, `viewWillLayoutSubviews` forwarders | One install method registers `.afterSuper` blocks with keys (`"cyl.core.viewWillAppear"` …); the overrides can go |
| `traitCollectionDidChange` → `cylTraitCollectionDidChange(from:)` | `.afterSuper` block reading `info.previousTraitCollection` |
| `didReceiveMemoryWarning` + `unloadsUnselectedViewsOnMemoryWarning` | `.afterSuper` block, flag checked inside |
| `viewWillTransition` work before `super` | `.beforeSuper` block reading `info.size` / `info.transitionCoordinator` |
| `viewDidLayoutSubviews` internal work | `.afterSuper` block |
| App's `viewDidLayoutSubviewsBlock` (+ invoke once, re-arm, FlatDesign early return) | `cyl_setManualLifecycleDispatch(true, for: [.viewDidLayoutSubviews], timings: [.end])`; setter = `cyl_addLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: invokeOnceViewDidLayoutSubViewsBlock, key: "cyl.core.layoutBlock")` (assigning the block with the flag off runs it on every layout, as today; `setViewDidLayoutSubViewsBlockInvokeOnce` passes `true`); dispatch with `cyl_invokeLifecycleCallbacks(for: .viewDidLayoutSubviews, timing: .end)` where the block runs today; re-arm = `cyl_rearmLifecycleCallback(key: "cyl.core.layoutBlock")` + its own `setNeedsLayout()` (re-arming by event would skip it, and must not re-run the app's own run-once blocks) |
| `deinit` → `cylStopObservingForDealloc()` with `isObserving…` flags | Where the observer is added: capture the observed object, `cyl_willDealloc(key:) { … observed.removeObserver(…) }`; no flag |
| Theme: `cyl_themeDidChange` per controller, `CYLThemeManagerCenter.updateThemes(for:)` | `.afterSuper` `traitCollectionDidChange` block; theme observers removed with keyed dealloc blocks |

### Design v3: nested overrides (advisor, 2026-11-22)

Found by the final review: with two overriding levels, v2 fired blocks twice or out of order (base and subclass both using `cyl_performLifecycle`; CYLTabBarController's raw `.end` inside an app subclass's `cyl_performLifecycle`). Same interface, new rules:

- The automatic hook always brackets UIKit with `.beforeSuper` / `.afterSuper`, also while `cyl_performLifecycle` runs.
- On a view controller, `cyl_performLifecycle` runs `callSuper`, then `body`, then `.end` only at its outermost level for the event, and not when `.end` is declared manual. Owners that are not view controllers (no hook) get all three timings from the outermost call.
- While `cyl_performLifecycle` runs, the automatic hook skips only `.end`.
- Limitation: a UIKit class whose override does not call `super` never reaches the hook. Seen: `UINavigationController.viewDidLayoutSubviews` (no `.afterSuper` / `.end`); its appearance events fire. `UITableViewController` fires `.afterSuper` and `.end`.

### Design v4: core / app isolation (advisor re-check, 2026-11-22)

- A block added with a key belongs to whoever holds the key. Cancel-all and re-arm by event touch only blocks without a key; keyed blocks are cancelled or re-armed by key: `cyl_cancelLifecycleCallback(key:)`, `cyl_rearmLifecycleCallback(key:)`, `cyl_cancelDeallocCallback(key:)`.
- Every 1.3.0 dealloc block has no key, so `cyl_cancelAllDeallocCallbacks()` keeps its 1.3.0 meaning.
- Convention: CYLTabBarController uses keys starting with `cyl.core.`; apps use their own keys or none. The library does not treat the prefix specially.
- Result: an app calling the broad cancel / re-arm calls on its CYLTabBarController subclass cannot remove the core's KVO teardown or layout block, and the core re-arming its layout block cannot re-run the app's run-once blocks.
- Swift Package Manager manifest added (`Package.swift`), so the core can depend on the library through SPM as through CocoaPods.

### CYLTabBarController mapping, v1 (not changed in this task)

| CYLTabBarController today | With this library |
| :-- | :-- |
| `viewDidLayoutSubviewsBlock` setter | Cancel the previous identifier, then `cyl_addLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: …)`; a new block still replaces the old one |
| Block run at the end of `cylViewDidLayoutSubviews` (skipped on the FlatDesign early return) | `cyl_setManualLifecycleDispatch(true, for: [.viewDidLayoutSubviews])` once, then `cyl_invokeLifecycleCallbacks(for: .viewDidLayoutSubviews, timing: .end, info:)` at the current block site, so the FlatDesign early return keeps skipping it |
| `invokeOnceViewDidLayoutSubViewsBlock` | `invokeOnce: true` |
| `-cyl_rearmViewDidLayoutSubviewsBlockInvokeOnce` | `cyl_rearmLifecycleCallbacks(for: .viewDidLayoutSubviews)`, then its own `view.setNeedsLayout()` |
| Theme observers removed in `deinit` | `cyl_willDealloc(callback:)` in the setter, as the README's skin demo does |

## Integration prerequisites (TODO, outside the score)

| Item | Status |
| :-- | :-- |
| Swift Package Manager: `Package.swift` (tools 5.9, iOS 15, one target), built with `xcodebuild -scheme CYLDeallocBlockExecutor -destination 'generic/platform=iOS Simulator'` from a copy without the `.xcodeproj`: BUILD SUCCEEDED, no warnings | DONE |
| Carthage: needs a shared framework scheme; the project only has the Example app target | TODO |
| Podspec platform: raised from iOS 9.0 to 15.0 (CYLTabBarController's minimum; the library needs iOS 11+ APIs and Xcode 27 builds 15.0+); `pod lib lint` (full build) passes | DONE |
| CI: `.github/workflows/ci.yml` (shellcheck, SPM, Example, `pod lib lint`, lifecycle tests Debug + Release) passes on `macos-26` | DONE |
| Version bump and tag (1.4.0) | TODO (maintainer) |
| Example app on iOS 27: no scene life cycle (`UIApplicationSceneManifest`), so it crashes at launch like the test app did before its scene delegate; old asset catalog warnings (1024 icon, launch images) | TODO |
| Integrate into CYLTabBarController (mapping above); not done here because another session owns that checkout | TODO |

## Scoring

Score = 100 × (rows of both tables whose last column is not `TODO`) / (all rows). Every row counts the same.

| Round | Step | Done / total | Score |
| :-- | :-- | :-- | :-- |
| 0 | Tables created | 0 / 25 | 0 |
| 1 | Search of the existing code (partial matches stay TODO) | 1 / 25 | 4 |
| 1b | Timing row added after the follow-up (denominator 25 → 26) | 1 / 26 | 4 |
| 1c | Design v2 rows added (manual per timing, replace by key; denominator 26 → 28) | 1 / 28 | 4 |
| 2 | Implementation + simulator tests (`Tests/run-lifecycle-tests.sh`, iOS 27.2, 26/26 checks, both swizzle orders) | 28 / 28 | 100 |
| 3a | Final review: nested overrides fire twice; "Manual dispatch" and "Automatic dispatch" back to partial (tests failed: nested perform, core raw `.end` inside app perform) | 26 / 28 | 93 |
| 3b | Design v3 + new tests (nested perform, core + app subclass, UIKit subclasses, KVO `observationInfo`): 31/31 on iOS 27.2 Debug and Release (`CYL_TEST_CONFIGURATION=release`) and iOS 17.5 Debug, both swizzle orders; podspec iOS 15.0, `pod lib lint` (full build) passes | 28 / 28 | 100 |
| 4a | Re-check audit: isolation row added (cancel-all / re-arm by event reach the core's keyed blocks) | 28 / 29 | 97 |
| 4b | Design v4 (keyed blocks owned by their key holder), `Package.swift`, README rows; 38/38 checks on iOS 27.2 Debug and Release and iOS 17.5 Debug, both swizzle orders; `pod lib lint` passes; README snippets typecheck | 29 / 29 | 100 |

## Lifecycle events

| Lifecycle method | Description | API / implementation |
| :-- | :-- | :-- |
| `viewDidLoad()` | Runs once the view controller has loaded its view. | `cyl_addLifecycleCallback(for: .viewDidLoad, timing:)`. Verified: `Tests/run-lifecycle-tests.sh` "automatic timings, no override", "automatic timings, override", "cyl_performLifecycle order, no double fire" |
| `viewWillAppear(_:)` | Runs before the view is added to the view hierarchy. | `.viewWillAppear`, `info.animated`. Verified: "appearance events fire", "core block inside an app subclass's super call", "info.animated set" |
| `viewIsAppearing(_:)` | Runs after the view is in the hierarchy and has its traits and geometry, before it is on screen (iOS 17+, back-deployed to iOS 13 by UIKit). | `.viewIsAppearing` (hooked only when UIKit has `viewIsAppearing:`). Verified: fired on iOS 27.2 (log line `viewIsAppearing fired: true`) |
| `viewDidAppear(_:)` | Runs after the view is on screen. | `.viewDidAppear`. Verified: "appearance events fire", "exchange swizzle after hooks: one fire, exchange runs" (both install orders) |
| `viewWillLayoutSubviews()` | Runs before the view lays out its subviews. | `.viewWillLayoutSubviews`. Verified: "order by identifier, cancel one", "cancel all" |
| `viewDidLayoutSubviews()` | Runs after the view has laid out its subviews. Must support "invoke once" plus re-arming, like `CYLTabBarController.invokeOnceViewDidLayoutSubViewsBlock` and `-cyl_rearmViewDidLayoutSubviewsBlockInvokeOnce`. | `.viewDidLayoutSubviews` with `invokeOnce:`, `key:`, `cyl_rearmLifecycleCallbacks(for:)`. Verified: "invoke once (manual end)", "re-arm runs an invoke-once block again", "replace by key (and replacement re-arms)" |
| `viewWillDisappear(_:)` | Runs before the view is removed from the view hierarchy. | `.viewWillDisappear`. Verified: "disappearance events" |
| `viewDidDisappear(_:)` | Runs after the view is removed from the view hierarchy. | `.viewDidDisappear`. Verified: "disappearance events" |
| `viewSafeAreaInsetsDidChange()` | Runs when the safe area insets of the view change. | `.viewSafeAreaInsetsDidChange`. Verified: "viewSafeAreaInsetsDidChange" |
| `viewLayoutMarginsDidChange()` | Runs when the layout margins of the view change. | `.viewLayoutMarginsDidChange`. Verified: "viewLayoutMarginsDidChange" |
| `traitCollectionDidChange(_:)` | Runs when the trait collection changes (dark mode, size class): the hook for re-applying a skin. | `.traitCollectionDidChange`, `info.previousTraitCollection` (selector by name, no iOS 17 deprecation warning). Verified: "traitCollectionDidChange with previous traits" (still called on iOS 27.2) |
| `viewWillTransition(to:with:)` | Runs before the view changes its size (rotation, split view). | `.viewWillTransition`, `info.size`, `info.transitionCoordinator`. Verified: "viewWillTransition with size (scene rotation)" |
| `willMove(toParent:)` | Runs before the controller is added to or removed from a container. | `.willMoveToParent`, `info.parent`. Verified: "willMove/didMove with parent" |
| `didMove(toParent:)` | Runs after the controller is added to or removed from a container. | `.didMoveToParent`, `info.parent`. Verified: "willMove/didMove with parent" |
| `didReceiveMemoryWarning()` | Runs when the app receives a memory warning. | `.didReceiveMemoryWarning`. Verified: "didReceiveMemoryWarning" |
| `dealloc` / `deinit` | Runs while the object is deallocated. Aligned with the other events: same `(owner, identifier)` block, same identifiers, same lock. | `cyl_willDealloc(callback:)` (owner, identifier, info: `isDealloc`, `.end`) and `cyl_willDealloc(key:callback:)`; 1.3.0 `cyl_willDealloc(selfCallback:)` unchanged. Verified: "one identifier sequence for dealloc and lifecycle", "dealloc order, info, keyed replacement" |

## Capabilities

| Capability | Description | API / implementation |
| :-- | :-- | :-- |
| Several blocks per object and event | Each object can hold any number of blocks for each event; they run in the order they were added. | `CYLCallbackModel` (one per object, every event). Verified: "order by identifier, cancel one" |
| Identifier and owner in every block | Every block receives the owner and its own identifier, as the dealloc block does (`CYLDeallocSelfCallback`). | `(owner, identifier, info)` for lifecycle and dealloc blocks. Verified: "order by identifier, cancel one", "dealloc order, info, keyed replacement" |
| Typed owner for live events | The owner can be received with its own type, like `CYLViewDidLayoutSubViewsBlock = (CYLTabBarController) -> Void`. | `CYLLifecycleCallbackOwner` protocol extension: `(Self, UInt, CYLLifecycleInfo)`. Verified: "typed owner" |
| Shared lock | Adding, cancelling and running use the lock of the dealloc API (`deallocCallbackLock`) and the per-object model lock. | `cylDeallocCallbackLock` (the dealloc lock) creates the model and hands out identifiers; `CYLCallbackModel.lock` guards entries; blocks run outside both. Verified: "add/cancel from inside a block" |
| Cancel one / cancel all | Cancel a block by its identifier, or all blocks of one event. | `cyl_cancelLifecycleCallback(identifier:)`, `cyl_cancelAllLifecycleCallbacks(for:timing:)`. Verified: "order by identifier, cancel one", "cancel all", "add/cancel from inside a block" |
| Invoke once and re-arm | A block can run only once; re-arming lets it run once more (the `invokeOnce` pattern of CYLTabBarController). | `invokeOnce:` + `cyl_rearmLifecycleCallbacks(for:timing:)`. Verified: "invoke once (manual end)", "re-arm runs an invoke-once block again" |
| Manual dispatch | The owner fires an event itself at the exact point it needs (CYLTabBarController runs its layout block at the end of its own `-viewDidLayoutSubviews`). | `cyl_performLifecycle(_:info:callSuper:body:)`, `cyl_invokeLifecycleCallbacks(for:timing:info:)`. Verified: "cyl_performLifecycle order, no double fire", "manual end after the override body", "nested cyl_performLifecycle fires each timing once", "core raw .end inside an app's cyl_performLifecycle" |
| Automatic dispatch | Any `UIViewController` fires the events without code in its overrides. | `UIViewController+CYLLifecycleHooks.swift` (`method_setImplementation`, previous IMP captured, installed lazily). Verified: "automatic timings, no override", exchange swizzle in both install orders |
| Timing (before super / after super / end) | Each block chooses when it runs: at the top before `super`, at the top after `super`, or at the end of the method. | `CYLLifecycleTiming` (`.beforeSuper`, `.afterSuper`, `.end`). Verified: "automatic timings, no override", "automatic timings, override", "cyl_performLifecycle order, no double fire" |
| Manual dispatch per timing | The owner can dispatch one timing of an event itself while the other timings of that event stay automatic. | `cyl_setManualLifecycleDispatch(_:for:timings:)`. Verified: "automatic afterSuper beside manual end" |
| Replace by key | Adding a block under a key replaces the block added before under that key (lifecycle and dealloc), so setters and install methods called twice keep one block. | `key:` on `cyl_addLifecycleCallback`, `cyl_willDealloc(key:callback:)`. Verified: "replace by key (and replacement re-arms)", "dealloc order, info, keyed replacement" |
| Core / app isolation | Keyed blocks belong to whoever holds the key: cancel-all and re-arm by event skip them, so an app cannot remove or re-run the core's blocks and the core cannot re-run the app's. | Keyed blocks skip `cyl_cancelAllLifecycleCallbacks(for:)`, `cyl_rearmLifecycleCallbacks(for:)` and `cyl_cancelAllDeallocCallbacks()`; owners use `cyl_cancelLifecycleCallback(key:)`, `cyl_rearmLifecycleCallback(key:)`, `cyl_cancelDeallocCallback(key:)`. Prefix `cyl.core.` reserved for CYLTabBarController by convention (not special-cased). Verified: "isolation: app cancel-all keeps the core's keyed blocks", "… keyed dealloc block", "isolation: core re-arms by key, app's run-once block stays fired", "isolation: re-arm by event skips keyed blocks", "cancel by key removes only that block", "cancel dealloc block by key" |
| Pure Swift | The whole library is Swift; no Objective-C file. | Already true: `CYLDeallocBlockExecutor/*.swift` only (round 1 search: no `.h` / `.m` in the repository) |
