> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Architecture shared by every platform

## Registry (one per owner)
- One identifier counter per owner, shared by lifecycle, custom and teardown blocks. iOS reserves `0` as the illegal identifier.
- Blocks run in identifier order from a snapshot. A lifecycle or custom block cancelled during a run is skipped, and one added during a run waits for the next fire.
- Teardown differs: once it has started, teardown blocks cannot be cancelled (docs/Usage-iOS.md:35; see F1 in 09-findings.md).
- **Keys:** adding with a key replaces the earlier block under that key; the new block starts unfired.
  - iOS has two key spaces: lifecycle (custom events included) and dealloc (`CYLCallbackModel.swift:121-148`).
  - The other ports have three: lifecycle, custom, dealloc (`kindOf` / `Kind`).
- **Keyed blocks belong to the key holder.** Cancel-all and re-arm-by-event skip them. Cancel or re-arm them by key.
- `invokeOnce` blocks run once until re-armed.

## Timings
| Timing | Meaning |
|---|---|
| beforeSuper | before the platform implementation |
| afterSuper (default) | after it |
| end | after the owner's own override |

- Only iOS (selector hooks) and the Flutter lifecycle methods (`initState`, `activate`, `deactivate`) really bracket `super`. Elsewhere `beforeSuper` and `afterSuper` fire back to back.
- `performLifecycle` runs `callSuper`, then `body`, then `end`. `end` fires only at the outermost level and not when `end` is declared manual.
- An owner without an automatic hook gets all three timings from the outermost `performLifecycle`.
- Manual dispatch is declared per (event, timing) pair; the automatic hook then skips that pair.

## Delivery order for one fire
1. The owner's own blocks.
2. Forwards: the target is held weakly; forwarding to the same target again replaces the earlier forward. A forwarded fire runs only the target's blocks (and the target's own forwards).
3. `LifecycleCenter` global observers, once, from the source. Forwarded fires skip them.

## LifecycleCenter
- Global observers filtered by event, timing and optionally owner type (Flutter uses a predicate, `ownerFilter`). Custom-event observers ignore timing.
- Global observers never receive teardown. Dealloc observers get a **description string** only, never the owner.
- `whileUserScrolls(pause, resume)` uses the keys `<key>.pause` and `<key>.resume` (default `cyl.scroll`). Calling it again replaces the pair; it returns a cancel function.
- `isUserScrolling` is a weak set of owners between `scrollWillBeginDragging` and `scrollDidEndScrolling`.

## Debug log and well-known names
- Off by default, messages built lazily, prefix `[CYLLifecycle]`.
- Custom names the library defines but never posts: `cyl.animation.didStart|didPause|didResume|didStop` and `cyl.badge.didShow|didClear|didBecomeReady|animationDidStart|animationDidStop`.

## Events
- 15 view-controller events: viewDidLoad, viewWillAppear, viewIsAppearing, viewDidAppear, viewWillLayoutSubviews, viewDidLayoutSubviews, viewWillDisappear, viewDidDisappear, viewSafeAreaInsetsDidChange, viewLayoutMarginsDidChange, traitCollectionDidChange, viewWillTransition, willMoveToParent, didMoveToParent, didReceiveMemoryWarning.
- 7 derived events (design v5): willMoveToWindow, didMoveToWindow, didEnterScreen, didLeaveScreen, scrollWillBeginDragging, scrollDidEndDragging, scrollDidEndScrolling.
- iOS only: appDidBecomeActiveOnScreen. So iOS has 23 events and each port has 22.

## Teardown trigger
| Platform | When teardown blocks run |
|---|---|
| iOS | when the owner deallocates (the associated callback model's deinit) |
| Android | `LifecycleController.destroy()` |
| Flutter | `State.dispose` |
| React Native | `detach()` (effect cleanup) |
| HarmonyOS | `aboutToDisappear()` |
| Mini Program | `onUnload()` |

Outside iOS, teardown is an explicit lifecycle call, not a garbage-collection event. An owner with no controller must call `runDealloc()` itself.
