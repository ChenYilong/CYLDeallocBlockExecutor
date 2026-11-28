> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# HarmonyOS
HAR module `HarmonyOS/cyldeallocblockexecutor` (`oh-package.json5`, entry `Index.ets`). The `.ts` sources use erasable syntax only, so Node runs them in tests through loader hooks. `entry/` is a demo app.

## Files
registry.ts, center.ts, controller.ts, types.ts, log.ts, index.ts (what Node imports), CYLLifecycleBridge.ets (exported by Index.ets only).

## Controller mapping (push model: the page forwards its callbacks)
| Event | Method |
|---|---|
| willMoveToParent, viewDidLoad, didMoveToParent | aboutToAppear() |
| viewWillAppear, viewIsAppearing, viewDidAppear, didEnterScreen | onPageShow(), back to back, animated false |
| viewWillDisappear, viewDidDisappear, didLeaveScreen | onPageHide() |
| viewWillTransition (size changed), viewDidLayoutSubviews | onAreaChange(old, new) |
| viewSafeAreaInsetsDidChange | avoidAreaChanged(insets) |
| traitCollectionDidChange | colorModeChanged(mode); the first value is only a baseline |
| didReceiveMemoryWarning | memoryLevel(level), critical = 2 |
| window moves | windowAttached(), windowDetached() |
| screen visibility | visibleAreaChanged(), setScreenVisible() |
| scroll | scrollStarted(), scrollStopped(); no drag-end source, so stop = end drag (no deceleration) + end |

No source: viewWillLayoutSubviews, viewLayoutMarginsDidChange.

## CYLLifecycleBridge
- `aboutToAppear(initialColorMode?)`: seeds the color mode so the first light-to-dark switch is reported (ColorMode 0 dark, 1 light).
- `attachWindow(win)`: subscribes `windowSizeChange` and `avoidAreaChange` (TYPE_SYSTEM) and unsubscribes in `aboutToDisappear`.
- Forward `onMemoryLevel` and `onConfigurationUpdate` from the UIAbility.

## Teardown
`aboutToDisappear()`: hide if shown, move events, `runDealloc()`. `isDetached` is then true.

## Demo notes
- In `EntryAbility.onBackPressed`, returning true only backgrounds the ability, so nothing is torn down; the demo returns false to destroy it.
- `onConfigurationUpdate` reads the delivered config because `context.config` is still stale then.
- The "Debug: simulate memory level" button exercises the handler only, not system delivery.
- The demo attaches the window only if `EntryAbility.win` (set asynchronously) is ready in `aboutToAppear` [read: Index.ets:35].

## Tests and build
Node: `node --import ./test/register.mjs --test "test/*.test.ts"` (47 / 47 pass). HAR: `scripts/build-har.sh` (macOS and DevEco-Studio paths). See 15-examples-and-tests.md and 14-device-evidence-and-scores.md.
