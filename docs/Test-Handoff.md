# Test handoff: everything to run once, per session

Written 2026-11-24 after the owner's rule: **write the code statically, then test everything in one pass, delivered once to
the sessions that can run it.** This file is that single delivery. Each platform lists what to run, what to record and what
"pass" means. Do not run partial passes; do not wait for CI; report one result block per platform.

## 0. Readiness gate and the SHA under test

The owner's rule: write the code statically, then test everything once. The sender delivers this file only when all five
hold (set by the advisor):

1. **G1 code complete:** the React Native Android memory source, the example guard, the crash capture, the score rows and this file are committed.
2. **G2 one SHA:** branch `integration/round-17` holds the heads of PRs #19 to #25 and the code branches; its head is **S**.
3. **G3 local static checks green on S** (no simulator, emulator or device): `node --test` for HarmonyOS, React Native and Mini Program (including the syntax guard); `tsc` for React Native; `flutter analyze` and `flutter test`, and `flutter analyze` in `Flutter/example`; `./gradlew :core:test :binding:testDebugUnitTest :example:assembleDebug`; the `swiftc` build of the test app in Debug and `-O` (not launched); `HarmonyOS/scripts/build-har.sh entry`.
4. **G4 docs** reference S.
5. **G5 no owner input needed for code:** the React Native memory design is chosen (host forwarding).

Everything below tests **S** (the delivery message names the SHA; replace `<MASTER>` with S). After S is tested, one CI run and
one merge commit follow, so S stays reachable for the pins.

Contents of S:
  - #19 HarmonyOS device app (dark mode, rotation, Back teardown, `aboutToAppear(initialColorMode?)`)
  - #20 Flutter example app
  - #21 iOS: a global scroll observer attaches to the scroll views already on screen
  - #22 Mini Program DevTools example
  - #23 React Native example app
  - #24 Mini Program: no class fields, `??`, `?.`; plain `require` index (WeChat DevTools drops files it cannot see referenced)
  - code branches: React Native Android memory source (`cylMemoryWarning`), example guard, crash capture in `Tests/run-lifecycle-tests.sh`
- Consumers re-pin once, to `<MASTER>` (iOS and text pins together; the Android pin cannot move alone: the CYLTabBarController
  1.100.0 artifact holds a strict constraint on `c85c10c`, so it moves with the 1.4.0 release).

## 1. Mac session (iOS), one pass

Clean build (empty derived data), own simulator, no `simctl shutdown all`.

| # | Run | Record | Pass |
|:-:|:--|:--|:--|
| 1 | Library suite from a fresh APFS clone at `<MASTER>`: `bash Tests/run-lifecycle-tests.sh <UDID>`, then `CYL_TEST_CONFIGURATION=release`; a launch that dies now prints its crash report | the two `RESULT:` lines (or the crash report) | 85 / 85 both |
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

## 3. Windows B items (emulators and Gradle), one pass, one heavy job at a time

Windows session B declined borrowed work without the owner's yes in its own session. Until the owner gives it, **the library
session runs these on the Mac emulators** (HarmonyOS and Android emulators exist on this Mac); a Windows run adds arm64 and a second machine.

| # | Run | Record | Pass |
|:-:|:--|:--|:--|
| 1 | HarmonyOS `HarmonyOS/entry` (hvigor, unsigned), Windows emulator, an arm64 image if available | `hilog` tag `CYL` | scroll begin / end pair up; dark / light give `traitCollectionDidChange`; rotation gives `viewSafeAreaInsetsDidChange`; Back with `onBackPressed` returning false gives `teardown`; memory level through DevEco Profiler gives `didReceiveMemoryWarning` |
| 2 | Android `Android/example` (list, `ScrollView` screen) | logcat tag `CYL` | dark, rotation, memory trim on both screens; fling pauses == resumes; `NestedScrollView` timer source |
| 3 | React Native `ReactNative/example` on an Android emulator | logs | flings pair up; mount, dark, rotation, teardown on `replace`; Home then `am send-trim-memory <package> RUNNING_LOW` gives `didReceiveMemoryWarning` once (the new `cylMemoryWarning` host event) |
| 4 | Flutter `Flutter/example` on an Android emulator | logs | the events already seen on macOS also appear here; `animationsPaused` native channel |

## 4. Open decisions (owner)

- **React Native, Android memory warning:** decided, host forwarding (`cylMemoryWarning` device event; example
  `MainApplication.kt`). It needs the test in section 3, row 3. Not an owner question any more.
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

## 7. Emulator start commands (verified 2026-11-24)

- HarmonyOS: `Emulator -hvd "Mate 70 Pro" -path ~/.Huawei/Emulator/deployed -imageRoot ~/Library/Huawei/Sdk` (a bare `-hvd` fails with "Unable to start the emulator").
- Android memory trim: on a fresh process send `RUNNING_LOW` first, then `MODERATE`; `am send-trim-memory` throws when the process is already past the level.
- Flutter on Android can deliver `didHaveMemoryPressure` more than once per trim: not a library bug.

## Round 18 handoff (2026-11-24, S = `d0e752a`, branch `integration/round-18`, PR #27)

Test **S = `d0e752a65692163da58f9c68dd8b6cfb51af9835`** in one pass; do not wait for CI. Report one block per platform (section 5 format) to the library session (`chenyilong-b8`). Deductions each row clears: [Cross-Platform-API.md, round 18 review](Cross-Platform-API.md#round-18-advisor-review-2026-11-24).

G3 compile gate on S (this Mac, 2026-11-24, load average about 750): Android `:example:assembleDebug` BUILD SUCCESSFUL (Gradle 8.14.3, JDK 21 from DevEco-Studio, AGP 8.13.0); HarmonyOS `entry` `assembleHap` BUILD SUCCESSFUL (hvigor, unsigned; one ArkTS warning, `EntryAbility.ets:21` may throw); React Native `tsc --noEmit --strict` on `ReactNative/example/App.tsx` clean after `yarn install` (the first S `fc935a7` had two navigation type errors, fixed). Row 4 of the Mac table is skipped: neither example has an `ios/` host project.

New in S (compiled, never run): Android `NestedScrollActivity`; React Native example on a React Navigation native stack (Home, Detail); HarmonyOS button "Debug: simulate memory level (handler only)".

### Mac session (iOS)

| # | Run | Pass |
|:-:|:--|:--|
| 1 | Library suite on S, fresh APFS clone: `bash Tests/run-lifecycle-tests.sh <UDID>`, then `CYL_TEST_CONFIGURATION=release` | 85 / 85 both |
| 2 | CYLTabBarController with iOS pins at S (local, not pushed): a screen with animated badge items, "Pause while scrolling" ON, 4 flicks | `cyl.badge.*` lines; badge pauses and resumes once per flick |
| 3 | Example-Rive Engine API page, **Loop ON**, pause while scrolling ON, flick | label `didPause` during the drag, `didResume` after |
| 4 | React Native example and Flutter example on the iOS simulator (iOS host) | appear / disappear (RN push Detail and Back), flings pair up, teardown |
| 5 | Screenshots of 2 to 4, original pixels, labeled, in `docs/assets/` | paths |

### Windows sessions (Android, Flutter, React Native, HarmonyOS, Mini Program)

| # | Run | Pass |
|:-:|:--|:--|
| 1 | Android `Android/example`: "open NestedScrollView (timer-based source)", `adb logcat -s CYL` | `ACT n` appear events; each drag or fling `SCROLLCOUNT` +1 pause, +1 resume; Back gives `ACT teardown`; arm64 image if available |
| 2 | React Native `ReactNative/example` (`yarn install` first: new dependencies), Android, `adb logcat -s ReactNativeJS` | launch: `viewWillAppear`, `viewIsAppearing`, `viewDidAppear`, `didEnterScreen` with `screen=Home`; push Detail: Home disappear + `didLeaveScreen`, Detail appear; Back: Detail disappear, `teardown screen=Detail`, Home appear; `replace`: `teardown screen=Home`; if `viewDidAppear` is missing at launch, report it (no `transitionEnd` for the initial route) |
| 3 | Flutter `Flutter/example` in a **profile** build (`flutter run --profile`) | three flings pair up; the round 16 events again |
| 4 | HarmonyOS `HarmonyOS/entry`, arm64 emulator if available: tap "Debug: simulate memory level (handler only)"; then DevEco Profiler memory level | `deliverMemoryLevel level=2`, `EVENT n didReceiveMemoryWarning` (hilog `CYL`); Profiler: the same lines without the tap |
| 5 | Mini Program (Windows A, logged in): section 2 rows 1 to 3 at S | events table of section 2; load problem gone or traced |
