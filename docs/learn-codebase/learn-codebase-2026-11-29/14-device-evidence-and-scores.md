> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Device-run evidence and scores (recorded in docs/Cross-Platform-API.md)
None of these runs were repeated for this export [doc]. Line numbers refer to that file.

## Two different scores
- **Cell score:** 205 / 205. A cell needs a named API plus a check that ran, or a platform N/A. It says nothing about whether the feature works on a device (the doc says this itself).
- **Effect score:** weighted (API 20, verified 25, real sources 15, consumer integration 25, docs and CI 15); never-run code earns at most half.

| Stage | iOS | Android | HarmonyOS | Flutter | React Native | Mini Program | Average |
|---|---|---|---|---|---|---|---|
| first audit (11-23) | 59 | 65 | 55 | 41 | 53 | 70 | about 57 |
| round 16 (11-24) | 85 | 95 | 85 | 72 | 72 | 84 | about 82 |
| round 17 | 87 | 97 | 92 | 90 | 82 | 84 | about 88.7 |
| after the round 17 pass | 89 | 98 | 92 | 90 | 88 | 84 | about 90.2 |
| round 18 on Mac | 89 | 99 | 93 | 94 | 97 | 84 | about 92.7 |
| round 18 Windows, Mini Program (latest, 11-27) | 89 | 99 | 93 | 94 | 97 | 97 | **about 94.8** |

The latest figures are labelled estimates. Round 19 in Test-Handoff.md lists the remaining runs; its projected scores differ because they assume those runs pass.

## What has been seen running
| Platform | Seen | Not seen |
|---|---|---|
| iOS | library suite 85 / 85 on simulators (later 89 / 89 in the task log); real-app flicks in CYLTabBarController pause and resume once each | real device; animated badge pause; Rive Loop label check |
| Android | API 35 emulator: lifecycle, Back teardown, dark mode, rotation, fragments, RecyclerView, ScrollView and NestedScrollView sources, memory trim (see F12) | real device; second machine |
| HarmonyOS | Mate 70 Pro x86_64 emulator: lifecycle, swipe and fling, dark / light, rotation, teardown when onBackPressed returns false | system memory level (only the debug button); arm64; real device |
| Flutter | Android emulator debug and profile; iOS simulator: lifecycle, flicks, push / back, dark mode, rotation, teardown through pushReplacement | native animationsPaused channels; the pushReplacement fix re-run on a device |
| React Native | Android emulator release build and iOS simulator: scroll, navigation chains, pop teardown, Android memory source | iOS simulated memory warning; native pause path |
| Mini Program | Windows DevTools 11 / 11; inside CYLTabBarController 12 UI tests pass, 3 fail, 3 skipped (the doc attributes none to this library) | real theme switch and rotation (forwarded calls only); wx.onMemoryWarning; real device |

## Tooling facts worth keeping
- am send-trim-memory works only on a background process and refuses a level at or below the current one.
- Flutter on Android can deliver memory pressure more than once per trim; the library does not dedupe.
- settings put system user_rotation did not rotate one emulator; cmd window user-rotation lock did.
- AGP 8.13 did not work with Gradle 9.9.2 and JDK 25; the wrapper (8.14.3) with JDK 21 did.
- The HarmonyOS emulator offers no command to send a memory level.
- DevTools: cli.bat needs a shell from Node 22; use --trust-project; Page.callMethod failed; high-latency networks needed the local proxy.
- CI: Maven Central returned HTTP 429 for the Robolectric runtime.
