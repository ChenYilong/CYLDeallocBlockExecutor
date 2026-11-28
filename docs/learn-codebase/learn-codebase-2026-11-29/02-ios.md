> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# iOS (reference implementation)
Swift, iOS 15+, 1.4.0. CocoaPods (podspec), SwiftPM (Package.swift) and Carthage (shared scheme). Sources in `CYLDeallocBlockExecutor/`.

## Files
| File | Role |
|---|---|
| NSObject+CYLDeallocBlockExecutor.swift | Public dealloc API, 1.3.0 deprecated shims, legacy `cyl_executeAtDealloc` |
| CYLDeallocExecutor.swift | Object that runs a closure in `deinit` (used by the legacy API) |
| CYLCallbackModel.swift | Per-object storage: dealloc blocks, lifecycle entries, keys, manual points, forwards |
| CYLLifecycle.swift | Events, timings, info, public lifecycle / custom / forwarding API |
| UIViewController+CYLLifecycleHooks.swift | Replaces UIViewController method implementations |
| CYLLifecycleSources.swift | Window hooks, visibility, scroll observer, app-became-active |
| CYLLifecycleCenter.swift | Global observers, dealloc observers, isUserScrolling |
| CYLLifecycleLog.swift | Debug log and well-known custom event names |

## Storage and locking
- `cylDeallocCallbackLock` (recursive, `CYLCallbackModel.swift:15`) guards model creation and identifier allocation (`:323-329`).
- The model has its own `NSLock`; blocks always run outside it, so a block can add or cancel blocks.
- The model holds the owner `Unmanaged` (unretained). Dealloc callbacks receive `Unmanaged<AnyObject>`: do not store it or let it escape.
- Model `deinit` (`:65-73`): walks the dealloc identifiers in sorted order, looks each block up again, then calls `CYLLifecycleCenter.dispatchDealloc`.

## Automatic view-controller hooks
- Installed once, on the first lifecycle block or global observer for a view-controller event. Dealloc-only users pay nothing.
- `method_setImplementation` / `class_addMethod` with the previous IMP captured and called, not selector exchange, so other swizzles keep working (`UIViewController+CYLLifecycleHooks.swift:93-150`). Tests run an exchange-style swizzle both before and after the hooks.
- `end` fires automatically only when the instance's class does not override the method (`:29-32, :67-69`). DEBUG builds print a warning if an `end` block is added to a class that overrides it.
- `traitCollectionDidChange` and `viewIsAppearing` selectors are reached by name. `viewIsAppearing` never fires where UIKit lacks it.
- After `viewDidAppear` / `viewDidDisappear` the hooks fire `didEnterScreen` / `didLeaveScreen`; on appear they also observe the content scroll view (`contentScrollView(for: .top)`, else the first scroll view found).

## Derived sources (installed on demand)
- **Window moves:** hooks on `UIView.willMove(toWindow:)` and `didMoveToWindow`. The fast path for an uninterested view is one associated-object read.
- **Visibility** (`CYLVisibilityState`): in a window, no hidden or alpha ≤ 0 ancestor, frame intersects the window and each enclosing scroll view. Re-evaluated on window moves, KVO of `isHidden` / `alpha`, and the nearest scroll view's `contentOffset`. Fires on changes only.
- **System bars:** views inside UITabBar, UINavigationBar or UIToolbar get no `isHidden` / `alpha` KVO (it would swap their class). Call `view.cylRefreshScreenState()` after changing them.
- **Scrolling** (`CYLScrollObserver`, `CYLLifecycleSources.swift:383-492`): never touches `UIScrollView.delegate`. Drag comes from a pan-gesture target; `willDecelerate` is read by a zero-delay timer on the next run-loop pass; a 60 Hz timer in `.common` mode polls `isDecelerating` for the end.
  - Subscribers are weak. Each runs its own blocks (fired as forwarded); the global observers hear the moment **once**, with the scroll view as owner.
  - Any other scroll view: `owner.cylObserveScrolling(of:)`.
  - A global scroll observer added late attaches to the scroll views already on screen (`:81-98`).
- **appDidBecomeActiveOnScreen:** one notification observer (name spelled as a string so app extensions compile); fires once per activation for on-screen owners with a block, plus visible view controllers when a global observer waits.

## Public API outline
- Dealloc: `cylWillDealloc(selfCallback:)`, `cylWillDealloc(callback:)`, `cylWillDealloc(key:callback:)`, `cylCancelDeallocCallback(identifier: / key:)`, `cylCancelAllDeallocCallbacks()`.
- Lifecycle: `cylAddLifecycleCallback(for:timing:invokeOnce:key:callback:)` with a typed owner, `cylAddLifecycleCallback(forCustomEvent:...)`, cancel / cancel-all / re-arm.
- Dispatch: `cylSetManualLifecycleDispatch`, `cylPerformLifecycle`, `cylInvokeLifecycleCallbacks` (asserts in DEBUG when a view controller's point was not declared manual and no perform is running).
- Custom and forwarding: `cylPostLifecycleEvent`, `cylForwardLifecycleEvents(_:to:)`.

## Gotchas
- A block stored on an object that captures that object is a retain cycle: use the `owner` parameter.
- Derived events fire at `afterSuper` only, `willMoveToWindow` included (it fires before the original method).
- The sources are main-thread only.
- If a scroll view is released while decelerating, the observer goes with it and no `scrollDidEndScrolling` is sent [read].
- `refreshFlags` (`CYLLifecycleCenter.swift:39-43`) does not count `appDidBecomeActiveOnScreen` as a view event; that event has its own install path.

## Demos
`Example/` and `CYLTabBarControllerTestDemo/` hold Swift demo apps.

## Tests
`Tests/LifecycleTests/main.swift` (773 lines) is a plain simulator app that prints `RESULT: PASS`. Run it with `bash Tests/run-lifecycle-tests.sh <UDID>`, also with `CYL_TEST_CONFIGURATION=release`. The latest task-log entry records 89 / 89 in Debug and Release (2026-11-26) [doc]; Test-Handoff.md still says 85. Not run here.
