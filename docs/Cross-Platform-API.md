# Cross-platform API

The iOS API ([Lifecycle-Callbacks.md](Lifecycle-Callbacks.md)) is the reference. This document maps each iOS feature to the matching API on every other platform and scores the progress. Task log: [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md#task-log). Created 2026-11-23, branch `feat/lifecycle-callbacks`, PR #12.

## Platforms

Android (Kotlin), Flutter (Dart), React Native (TypeScript), HarmonyOS (ArkTS), WeChat Mini Program. Implementations live in this repository, one folder per platform. The folders under `CYLTabBarController/CrossPlatform/` are read-only evidence for the search step (another session owns that checkout).

## Score

Score = 100 × (scored cells that are not `TODO`) ÷ (all scored cells). 29 rows × 5 platforms = 145 cells; the iOS column is the reference and is not scored. A per-platform score is shown beside the total so each platform's progress is visible.

A cell counts only when it has evidence:

1. **API plus check.** It names an API that exists in the code of this repository and a test or build check that ran (name the command or test). A name written into a cell with no code behind it stays `TODO`.
2. **`N/A: <reason>`.** The platform has no such event or concept, with the platform reason stated (for example, the Mini Program has no safe-area-insets-changed event). It counts as done.
3. **Dealloc on garbage-collected platforms.** There is no deterministic equivalent of `dealloc`. The cell maps to the explicit teardown event (`onDestroy`, `dispose`, `aboutToDisappear`, `onUnload`) and says that a finalizer is best-effort only. It does not claim parity.
4. Naming follows `instructions.md` "Other languages": no member prefix in Kotlin, Dart and TypeScript; a prefix only on global strings (channel names, resources, component tags, event names).
5. A platform that cannot be verified here keeps its cells `TODO`, and the reason is written under "Progress".

| Round | Step | Android | Flutter | RN | HarmonyOS | Mini Program | Total | Score |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| 0 | Tables created | 0 / 29 | 0 / 29 | 0 / 29 | 0 / 29 | 0 / 29 | 0 / 145 | 0 |

## Progress

Round 0: tables generated from the two iOS tables. Next: round 1, search the existing code for matches (read-only in `CYLTabBarController/CrossPlatform/*`), then the advisor's per-platform design.

## Table

### Lifecycle events

| iOS feature | Description | iOS API (reference, not scored) | Android (Kotlin) | Flutter (Dart) | React Native (TS) | HarmonyOS (ArkTS) | WeChat Mini Program |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| `viewDidLoad()` | Runs once the view controller has loaded its view. | `cylAddLifecycleCallback(for: .viewDidLoad, timing:)` | TODO | TODO | TODO | TODO | TODO |
| `viewWillAppear(_:)` | Runs before the view is added to the view hierarchy. | `.viewWillAppear`, `info.animated` | TODO | TODO | TODO | TODO | TODO |
| `viewIsAppearing(_:)` | Runs after the view is in the hierarchy and has its traits and geometry, before it is on screen (iOS 17+, back-deployed to iOS 13 by UIKit). | `.viewIsAppearing` (hooked only when UIKit has `viewIsAppearing:`) | TODO | TODO | TODO | TODO | TODO |
| `viewDidAppear(_:)` | Runs after the view is on screen. | `.viewDidAppear` | TODO | TODO | TODO | TODO | TODO |
| `viewWillLayoutSubviews()` | Runs before the view lays out its subviews. | `.viewWillLayoutSubviews` | TODO | TODO | TODO | TODO | TODO |
| `viewDidLayoutSubviews()` | Runs after the view has laid out its subviews. Must support "invoke once" plus re-arming, like `CYLTabBarController.invokeOnceViewDidLayoutSubViewsBlock` and `-cyl_rearmViewDidLayoutSubviewsBlockInvokeOnce`. | `.viewDidLayoutSubviews` with `invokeOnce:`, `key:`, `cylRearmLifecycleCallbacks(for:)` | TODO | TODO | TODO | TODO | TODO |
| `viewWillDisappear(_:)` | Runs before the view is removed from the view hierarchy. | `.viewWillDisappear` | TODO | TODO | TODO | TODO | TODO |
| `viewDidDisappear(_:)` | Runs after the view is removed from the view hierarchy. | `.viewDidDisappear` | TODO | TODO | TODO | TODO | TODO |
| `viewSafeAreaInsetsDidChange()` | Runs when the safe area insets of the view change. | `.viewSafeAreaInsetsDidChange` | TODO | TODO | TODO | TODO | TODO |
| `viewLayoutMarginsDidChange()` | Runs when the layout margins of the view change. | `.viewLayoutMarginsDidChange` | TODO | TODO | TODO | TODO | TODO |
| `traitCollectionDidChange(_:)` | Runs when the trait collection changes (dark mode, size class): the hook for re-applying a skin. | `.traitCollectionDidChange`, `info.previousTraitCollection` (selector by name, no iOS 17 deprecation warning) | TODO | TODO | TODO | TODO | TODO |
| `viewWillTransition(to:with:)` | Runs before the view changes its size (rotation, split view). | `.viewWillTransition`, `info.size`, `info.transitionCoordinator` | TODO | TODO | TODO | TODO | TODO |
| `willMove(toParent:)` | Runs before the controller is added to or removed from a container. | `.willMoveToParent`, `info.parent` | TODO | TODO | TODO | TODO | TODO |
| `didMove(toParent:)` | Runs after the controller is added to or removed from a container. | `.didMoveToParent`, `info.parent` | TODO | TODO | TODO | TODO | TODO |
| `didReceiveMemoryWarning()` | Runs when the app receives a memory warning. | `.didReceiveMemoryWarning` | TODO | TODO | TODO | TODO | TODO |
| `dealloc` / `deinit` | Runs while the object is deallocated. Aligned with the other events: same `(owner, identifier)` block, same identifiers, same lock. | `cylWillDealloc(callback:)` (owner, identifier, info: `isDealloc`, `.end`) and `cylWillDealloc(key:callback:)`; 1.3.0 `cylWillDealloc(selfCallback:)` unchanged | TODO | TODO | TODO | TODO | TODO |

### Capabilities

| iOS feature | Description | iOS API (reference, not scored) | Android (Kotlin) | Flutter (Dart) | React Native (TS) | HarmonyOS (ArkTS) | WeChat Mini Program |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| Several blocks per object and event | Each object can hold any number of blocks for each event; they run in the order they were added. | `CYLCallbackModel` (one per object, every event) | TODO | TODO | TODO | TODO | TODO |
| Identifier and owner in every block | Every block receives the owner and its own identifier, as the dealloc block does (`CYLDeallocSelfCallback`). | `(owner, identifier, info)` for lifecycle and dealloc blocks | TODO | TODO | TODO | TODO | TODO |
| Typed owner for live events | The owner can be received with its own type, like `CYLViewDidLayoutSubViewsBlock = (CYLTabBarController) -> Void`. | `CYLLifecycleCallbackOwner` protocol extension: `(Self, UInt, CYLLifecycleInfo)` | TODO | TODO | TODO | TODO | TODO |
| Shared lock | Adding, cancelling and running use the lock of the dealloc API (`deallocCallbackLock`) and the per-object model lock. | `cylDeallocCallbackLock` (the dealloc lock) creates the model and hands out identifiers; `CYLCallbackModel.lock` guards entries; blocks run outside both | TODO | TODO | TODO | TODO | TODO |
| Cancel one / cancel all | Cancel a block by its identifier, or all blocks of one event. | `cylCancelLifecycleCallback(identifier:)`, `cylCancelAllLifecycleCallbacks(for:timing:)` | TODO | TODO | TODO | TODO | TODO |
| Invoke once and re-arm | A block can run only once; re-arming lets it run once more (the `invokeOnce` pattern of CYLTabBarController). | `invokeOnce:` + `cylRearmLifecycleCallbacks(for:timing:)` | TODO | TODO | TODO | TODO | TODO |
| Manual dispatch | The owner fires an event itself at the exact point it needs (CYLTabBarController runs its layout block at the end of its own `-viewDidLayoutSubviews`). | `cylPerformLifecycle(_:info:callSuper:body:)`, `cylInvokeLifecycleCallbacks(for:timing:info:)` | TODO | TODO | TODO | TODO | TODO |
| Automatic dispatch | Any `UIViewController` fires the events without code in its overrides. | `UIViewController+CYLLifecycleHooks.swift` (`method_setImplementation`, previous IMP captured, installed lazily) | TODO | TODO | TODO | TODO | TODO |
| Timing (before super / after super / end) | Each block chooses when it runs: at the top before `super`, at the top after `super`, or at the end of the method. | `CYLLifecycleTiming` (`.beforeSuper`, `.afterSuper`, `.end`) | TODO | TODO | TODO | TODO | TODO |
| Manual dispatch per timing | The owner can dispatch one timing of an event itself while the other timings of that event stay automatic. | `cylSetManualLifecycleDispatch(_:for:timings:)` | TODO | TODO | TODO | TODO | TODO |
| Replace by key | Adding a block under a key replaces the block added before under that key (lifecycle and dealloc), so setters and install methods called twice keep one block. | `key:` on `cylAddLifecycleCallback`, `cylWillDealloc(key:callback:)` | TODO | TODO | TODO | TODO | TODO |
| Core / app isolation | Keyed blocks belong to whoever holds the key: cancel-all and re-arm by event skip them, so an app cannot remove or re-run the core's blocks and the core cannot re-run the app's. | Keyed blocks skip `cylCancelAllLifecycleCallbacks(for:)`, `cylRearmLifecycleCallbacks(for:)` and `cylCancelAllDeallocCallbacks()`; owners use `cylCancelLifecycleCallback(key:)`, `cylRearmLifecycleCallback(key:)`, `cylCancelDeallocCallback(key:)`. Prefix `cyl.core.` reserved for CYLTabBarController by convention (not special-cased) | TODO | TODO | TODO | TODO | TODO |
| Pure Swift | The whole library is Swift; no Objective-C file. | Already true: `CYLDeallocBlockExecutor/*.swift` only (round 1 search: no `.h` / `.m` in the repository) | TODO | TODO | TODO | TODO | TODO |
