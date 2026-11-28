> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Android
`Android/core` is pure Kotlin/JVM (no Android types). `Android/binding` feeds it from real callbacks (minSdk 21, compileSdk 34, androidx.fragment; RecyclerView is compileOnly). Kotlin plugin 2.4.0 and AGP 8.13.0; compiled for Kotlin 2.0 with stdlib 2.0.21 so that CYLTabBarController can consume it. `settings.gradle.kts` includes `:binding` and `:example` only when an SDK is configured.

## Core
- `LifecycleRegistry.of(owner)` keys owners by **identity** (`identityHashCode` buckets), so equal data-class owners get separate registries. Dead buckets are purged on each `of()` call.
- Locked internally; blocks run outside the lock.
- `LifecycleLog.describer` can be replaced to name owners.
- `LifecycleInfo` adds `previousNightMode`, `previousFontScale`, `previousInsets`, `trimLevel`.

## Controller mapping
| Event | Controller method | Real source (binding) |
|---|---|---|
| willMoveToParent / didMoveToParent | attach(), destroy() | onFragmentAttached; Activity attaches in create() |
| viewDidLoad | create() | onActivityCreated, onFragmentViewCreated |
| viewWillAppear | start() | onStart |
| viewIsAppearing | resume() | onResume |
| viewDidAppear, then didEnterScreen | resumedAndDrawn() | Activity: pre-draw then post; Fragment: view.post |
| viewWillDisappear | pause() | onPause |
| viewDidDisappear, then didLeaveScreen | stop() | onStop |
| viewDidLayoutSubviews, safe-area insets | layout(), insetsChanged() | decor global-layout listener (Activities, while started) |
| viewWillTransition, traitCollectionDidChange | configurationChanged() | ComponentCallbacks2 (delivered to Activities) |
| didReceiveMemoryWarning | trimMemory(level) | onTrimMemory at RUNNING_CRITICAL or higher except UI_HIDDEN; onLowMemory |

- Unlike iOS, returning from the background fires the appear events again.
- No source: viewWillLayoutSubviews, viewLayoutMarginsDidChange.
- Configuration is read from the delivered `newConfig`, because the activity's resources are still stale in that callback (found on a device [doc: code comment]).
- Insets are read from `rootWindowInsets` (API 23+) without installing an insets listener, so the app's listener is not replaced. `insetsProvider` is replaceable in tests.

## Setup and helpers
- Call `AndroidBinding.install(application)` once in `Application.onCreate`.
- `observeWindow(owner, view)`, `observeVisibility(owner, view)`.
- `observeScrolling(owner, recyclerView)`: maps DRAGGING / SETTLING / IDLE and returns a stop function.
- `observeScrolling(owner, view, idleDelayMillis = 150)`: for other scroll containers; the first scroll change begins and 150 ms of quiet ends (`willDecelerate = false`). The view must already be attached.

## Teardown
`destroy()` (`LifecycleController.kt:154-162`): sets `destroyed`, flushes the pending did events, fires the move events, then `runDealloc()`. The binding then drops the controller.

## Risks (details in 09-findings.md)
observeWindow and observeVisibility stack listeners; a pending appear survives stop(), so viewDidAppear can arrive after viewDidDisappear; a quick pause can still send didEnterScreen; because of the static registry map, blocks must use the owner parameter and not capture the owner.

## Build helpers
`Android/scripts/gradle.sh` and `test-mirror.sh` are macOS-specific (Android Studio JBR; copy to an APFS folder because the source volume is exFAT).

## Tests and example
See 15-examples-and-tests.md.
