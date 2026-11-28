> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# React Native
`ReactNative/src` in TypeScript, 1.4.0, private package, `react-native` an optional peer. `erasableSyntaxOnly` lets Node run the sources.

## Files
| File | Role |
|---|---|
| registry.ts / center.ts / types.ts / log.ts | the shared design |
| controller.ts | LifecycleController; all platform sources are injected (PlatformSources) |
| native.ts | the only file that imports react and react-native: createNativeSources, useLifecycle; not run by Node tests |
| index.ts | public exports, without native.ts |
| typings/react-native.d.ts | five-name stub so typecheck needs no react-native install |

## useLifecycle(owner, { navigation, safeAreaInsets, navigationMode })
- Mounts a new controller in an effect and unmounts it in cleanup, so StrictMode's mount, unmount, mount works. The first unmount runs the teardown blocks, which are then gone.
- Returns `registry`, `onLayout`, `scrollHandlers` (spread onto ScrollView or FlatList), `setScreenVisible`.
- The effect depends on the **identity** of owner, navigation, safeAreaInsets and navigationMode (`native.ts:47`): keep them stable (see findings).

## Sources
- **Navigation** (React Navigation object): `focus` gives will + isAppearing, `blur` gives will disappear. In `stack` mode (default) `transitionStart` / `transitionEnd` with `data.closing` give the will and did events; tab navigators send no data and count as appear. In `immediate` mode focus and blur complete the whole sequence. A small state machine keeps the order whichever source arrives first.
- App foreground and background never fire appear events.
- **Sources are subscribed lazily** on the first block for their event and removed in `detach()`.
- **Memory:** iOS uses AppState `memoryWarning`; other platforms use the DeviceEventEmitter event `cylMemoryWarning` (`MEMORY_WARNING_EVENT`) emitted by the host. Never both.
- Dimensions gives viewWillTransition; font scale and Appearance give traitCollectionDidChange. Safe-area insets need an injected source. viewLayoutMarginsDidChange and viewWillLayoutSubviews have no source. viewDidLayoutSubviews comes from onLayout. The window events have no source.
- **Scroll:** begin-drag; end-drag with `willDecelerate` from a non-zero velocity (ends at once when false); momentum end finishes it.

## Teardown
`detach()`: flush pending did events; if visible, send the disappear events (pop and replace give no blur); move events; remove sources; `runDealloc()`.

## Example (ReactNative/example)
React Native 0.88 [doc], native stack with Home (400-row FlatList) and Detail; Metro watches the parent folder. Log lines `CYL EVENT n name screen=...`. `MainActivity` calls `super.onCreate(null)` (react-native-screens crashes when restoring saved fragments). `MainApplication` forwards memory trim. There are iOS host files (AppDelegate, SceneDelegate, Podfile) although the example README says there are none.

## Tests
`node --test "test/*.test.ts"`: 56 / 56 pass, using fake platform sources (no device behaviour covered).
