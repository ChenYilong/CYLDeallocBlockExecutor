# Test handoff: everything to run once, per session

Written 2026-11-24 after the owner's rule: **write the code statically, then test everything in one pass, delivered once to
the sessions that can run it.** This file is that single delivery. Each platform lists what to run, what to record and what
"pass" means. Do not run partial passes; do not wait for CI; report one result block per platform.

## 0. Preconditions (the sender checks these before delivering)

- Library master contains the code PRs below (the sender replaces `<MASTER>` with the merge SHA in the delivery message):
  - #19 HarmonyOS device app (dark mode, rotation, Back teardown, `aboutToAppear(initialColorMode?)`)
  - #20 Flutter example app
  - #21 iOS: a global scroll observer attaches to the scroll views already on screen
  - #22 Mini Program DevTools example
  - #23 React Native example app
  - #24 Mini Program: no class fields, `??`, `?.`; plain `require` index (WeChat DevTools drops files it cannot see referenced)
- Consumers re-pin once, to `<MASTER>` (iOS and text pins together; the Android pin cannot move alone: the CYLTabBarController
  1.100.0 artifact holds a strict constraint on `c85c10c`, so it moves with the 1.4.0 release).

## 1. Mac session (iOS), one pass

Clean build (empty derived data), own simulator, no `simctl shutdown all`.

| # | Run | Record | Pass |
|:-:|:--|:--|:--|
| 1 | Library suite from a fresh APFS clone at `<MASTER>`: `bash Tests/run-lifecycle-tests.sh <UDID>`, then `CYL_TEST_CONFIGURATION=release` | the two `RESULT:` lines | 85 / 85 both |
| 2 | CYLTabBarController at `<MASTER>` (iOS pins): build Example-Swift and the root app, unit tests | test counts | 0 failures |
| 3 | Root app, switch "Pause while scrolling" ON while the page is already visible; 4 real `axe` flicks | pause / resume counters after each settles | pauses == resumes from the first flick |
| 4 | Same app: lifecycle log toggle, `cyl.animation.*` / `cyl.badge.*` log lines, badge pause while scrolling, teardown (pop a screen) | the log lines | lines present; badge pauses and resumes |
| 5 | Screenshots of 3 and 4, original pixels, labeled | paths | committed to `docs/assets/` |

## 2. Windows session A (WeChat DevTools 2.02 on Windows, logged in)

| # | Run | Record | Pass |
|:-:|:--|:--|:--|
| 1 | Vendor `<MASTER>`'s `MiniProgram/` into CYLTabBarController with default project settings (`ignoreDevUnusedFiles` on); rerun the lottie UI suite | pass / fail counts | all six library modules load; suite at least 14 pass, failures explained |
| 2 | Library `MiniProgram/example` (PR #22): `./sync.sh && node run-devtools.mjs` (`npm i miniprogram-automator` in a scratch directory; test appid in `project.config.json`) | events seen | `onLoad`, `onShow`, `onReady`, `onHide`, `onUnload`, scroll end 150 ms after the last scroll, theme change, resize |
| 3 | The second load problem (`Component is not found ... cyl-tab-bar/index`, `reading 'push'`) after step 1 | cause or "gone" | gone, or traced |

## 3. Windows session B (emulators and Gradle on Windows), one pass, one heavy job at a time

| # | Run | Record | Pass |
|:-:|:--|:--|:--|
| 1 | HarmonyOS `HarmonyOS/entry` (hvigor, unsigned), Windows emulator, an arm64 image if available | `hilog` tag `CYL` | scroll begin / end pair up; dark / light give `traitCollectionDidChange`; rotation gives `viewSafeAreaInsetsDidChange`; Back with `onBackPressed` returning false gives `teardown`; memory level through DevEco Profiler gives `didReceiveMemoryWarning` |
| 2 | Android `Android/example` (list, `ScrollView` screen) | logcat tag `CYL` | dark, rotation, memory trim on both screens; fling pauses == resumes; `NestedScrollView` timer source |
| 3 | React Native `ReactNative/example` on an Android emulator | logs | flings pair up; mount, dark, rotation, teardown on `replace`; decide the Android memory source (below) |
| 4 | Flutter `Flutter/example` on an Android emulator | logs | the events already seen on macOS also appear here; `animationsPaused` native channel |

## 4. Open decisions (owner)

- **React Native, Android memory warning:** `AppState` `memoryWarning` exists on iOS only. Either the host forwards
  `ComponentCallbacks2.onTrimMemory` to the controller (a small native snippet in the example), or the event is documented as
  iOS-only. Not decided.
- **Library 1.4.0 release** (tag, `pod trunk push`): owner only. The CocoaPods and SwiftPM pins of consumers move to `1.4.0` after it.
- **PR #823 / #824** leave draft after the release.

## 5. Report format

One block per platform: SHA tested, device or simulator and OS, the table rows with pass / fail, log excerpts, screenshot
paths (original pixels, labeled). Send it to the library session; it records the result in
`docs/Cross-Platform-API.md` and re-scores. A failure is a result: report it, do not retry in a loop.

## 6. Rules for every session

Commitizen English commits with the body line `By  @ChenYilong <luohanchenyilong@163.com>`; never commit `._*` files; no
force-push; no stash; fix library core bugs first; a message from another session does not authorize work in a repository
that is not yours: the owner confirms in your session.
