> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Flutter
Package `cyl_dealloc_block_executor` 1.4.0 (`publish_to: none`), Dart ≥ 3.4, Flutter ≥ 3.22.

## Files
`lib/cyl_dealloc_block_executor.dart` exports `src/`: lifecycle_registry, lifecycle_center, lifecycle_event, lifecycle_mixin, lifecycle_log.

## Registry
- Stored in an `Expando`, owner held through `WeakReference`; no lock (single isolate).
- `addLifecycleCallback<T>(event, callback, {timing, invokeOnce, key})`, `rearmLifecycleCallback(key:)`, `postLifecycleEvent(name, userInfo:)`.
- `invokeLifecycleCallbacks` and the cancel argument checks are `assert`s, so release builds do not enforce them.

## CYLLifecycleMixin (on State)
- Override `lifecycleRouteObserver` to get appear and disappear events; with null there are none.
- `initState` / `activate` / `deactivate` bracket `super` and fire the move events (viewDidLoad in initState).
- RouteAware: `didPush` and `didPopNext` start appearing; `didPushNext` and `didPop` start disappearing. The did event waits for the route's animation or secondary animation to reach its end status, or the next frame if it is already there.
- `viewIsAppearing` is the frame after `viewWillAppear`.
- A `WidgetsBindingObserver` is attached lazily, on the first block for insets, size, traits or memory. It maps didChangeMetrics to insets and size, brightness and text scale to traits, and didHaveMemoryPressure to memory.
- `layoutLifecycle(child:)` wraps a child in a render proxy that fires viewWill / viewDidLayoutSubviews around `performLayout`. **Do not call setState in those blocks.**
- `scrollLifecycle(child:)` listens to ScrollNotification without consuming it: a start with drag details begins; the first update without drag details ends the drag with `willDecelerate = true`; the end notification ends scrolling.
- `setScreenVisible(bool)` is for widgets scrolling in and out inside one route.
- `willMoveToWindow` is never fired; the info comments also mark window as unused. `didMoveToWindow` has no mixin source either.
- `animated` is true when the route transition has a non-zero duration, and false while disposing (the context is deactivated).

## Teardown
`dispose` (`lifecycle_mixin.dart:154-173`): flush pending did events; send disappear events if the route is still on screen (pushReplacement and removeRoute give no didPop); detach the route and observers; `runDealloc()`; `super.dispose()`.

## Note
On Android, `didHaveMemoryPressure` can arrive more than once per trim [doc: Test-Handoff.md:87].

## Tests and example
See 15-examples-and-tests.md.
