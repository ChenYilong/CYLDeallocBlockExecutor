> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Build, CI and scripts

## CI (.github/workflows/ci.yml): pull requests, pushes to master, manual
| Job | Runner | What it does |
|---|---|---|
| shellcheck | ubuntu | shellcheck Tests/*.sh |
| build | macos-26 | Swift package built from a copy with warnings as errors (xcodebuild would pick the .xcodeproj); library target of the project |
| carthage | macos-26 | xcframework build |
| lint | macos-26 | pod lib lint |
| lifecycle-tests | macos-26 | debug and release matrix on a booted simulator |
| node-suites | ubuntu, Node 22 | RN, HarmonyOS, Mini Program (the file comment "written without a CI run" is stale: Cross-Platform-API.md reports green CI Node suites) |
| android | ubuntu, Java 21 | :core:test and :binding:testDebugUnitTest |
| flutter | ubuntu, stable | pub get, analyze, test |
- The repository variable `MACOS_RUNNER` overrides the macOS image.

## Local test commands
```
cd ReactNative && node --test "test/*.test.ts"
cd HarmonyOS && node --import ./test/register.mjs --test "test/*.test.ts"
cd MiniProgram && node --test "test/*.test.js"
cd Android && ./gradlew :core:test :binding:testDebugUnitTest
cd Flutter && flutter pub get && flutter analyze && flutter test
bash Tests/run-lifecycle-tests.sh <simulator UDID>
CYL_TEST_CONFIGURATION=release bash Tests/run-lifecycle-tests.sh <simulator UDID>
pod lib lint
```

## iOS test script
Compiles library plus main.swift with swiftc into a temporary simulator app, then launches twice (exchange swizzle after, then before, the hooks with `-exchangeFirst`). A log without RESULT prints the log tail and newest crash report. See F14.

## Packaging
- podspec: 1.4.0, iOS 15, Swift 5.0. Package.swift: tools 5.9, same sources.
- jitpack.yml builds the Android modules with JDK 17. Its "not run yet" comment is stale: Cross-Platform-API.md:233 reports a successful JitPack build of c85c10c [doc]. Artifacts: cyl-dealloc-block-executor-core and -android.
- Offline Robolectric: set `CYL_ROBOLECTRIC_DIR`. The runtime jar comes from Google's Maven Central mirror because shared CI runners got HTTP 429.

## Machine-specific helpers
- Android/scripts/gradle.sh, test-mirror.sh and HarmonyOS/scripts/build-har.sh assume macOS paths; the last two copy to APFS because the source volume is exFAT.
- Windows Mini Program: see 07-miniprogram.md (proxy, cli.bat spawn, --trust-project).

## Test handoff (docs/Test-Handoff.md) [doc]
- Owner rule: write code statically, then test everything in one pass per platform; do not wait for CI.
- Windows emulator and DevTools runs hold the lock a shared lock file (local path omitted).
- **Round 19 (2026-11-27)** lists the remaining runs. Library code: 5ba2813, and 5767e41 for the Mini Program.

| Row | Platform | Run |
|---|---|---|
| 1 | iOS | CYLTabBarController animated badges pause and resume once per flick |
| 2 | iOS | Example-Rive Loop ON: didPause while dragging, didResume after |
| 3 | React Native | iOS host: simulated memory warning logged once |
| 4 | Flutter | CYLTabBarController animationsPaused channel on an Android emulator |
| 5 | React Native | the same native path in its wrapper |
| 6 | HarmonyOS | real memory level through DevEco Profiler |
| 7 | Android | second-machine run: dark, rotation, RUNNING_LOW, flings |
| 8 | Mini Program | real DevTools theme, rotation and memory warning |
- Owner only: the 1.4.0 tag and pod trunk push, PR merge order, real devices, the cause of the Mini Program load problem.
- These are the doc's statements. I did not check whether any row has since been run.
- Emulator tip: on a fresh Android process send RUNNING_LOW before MODERATE.
