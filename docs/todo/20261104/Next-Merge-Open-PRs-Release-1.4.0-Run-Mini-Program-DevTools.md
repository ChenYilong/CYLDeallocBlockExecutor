# Handoff: your next focus is to merge the open PRs, release 1.4.0, and run the Mini Program in DevTools

Written 2026-11-26 (week 4 of November) for the next developer of CYLDeallocBlockExecutor.

Folder rule: `docs/todo/<year><month><week of month>`, so `20261104` is November 2026, week 4 (days 22 to 28: `ceil(day / 7)`).
This week's folder holds **one file only**: append to this file, do not add another one.

## 0. Do these first (in order)

1. **Copy what is only on the old Mac** before the machine is reassigned (section 8: other repositories' patches, memory notes). `/tmp` does not survive a reboot.
2. **Get CI green and merge**: #27, then #28; #30, then #29 (retarget #29 to `master` after #30). Decide the order first (section 7).
3. **Decide the release scope** (1.4.0 with or without the two new events), then tag and `pod trunk push`. Owner permission is required.
4. **Run the Mini Program** example in WeChat DevTools on the logged-in Windows machine, and trace `Component is not found`.
5. **Close the HarmonyOS memory gap** with DevEco Profiler, then re-score.

## 1. Scores

These are advisor estimates of 2026-11-26, made from repository and CI state, not from a new test run.

| Measure | Score |
| :-- | --: |
| Effect (how well the features work, six platforms, average) | **92.2 / 100** |
| Release readiness (distance to a publishable 1.4.0) | **70 / 100** |

The interface-coverage cell score in [Cross-Platform-API.md](../../Cross-Platform-API.md) is 100: it counts filled API-and-test cells, not device proof.

### Release readiness: the 30 missing points

| Points | Miss point |
| --: | :-- |
| 7 | Nothing merged since master `4276a6d`. #27 passes 9 of 9 checks but is open; #28, #29, #30 had 4 checks passed and 5 pending when this was written. Merge order and retargets are undecided (#28 is based on `integration/round-18`, #29 on #30) |
| 7 | 1.4.0 is not tagged or published. The podspec already says 1.4.0, so SwiftPM, Carthage and CocoaPods trunk users are blocked. Consumers pin commits (CYLTabBarController #823 / #824 are drafts; CYLSearchViewController pins `eab21d1`). 1.4.0 or 1.5.0 for the new events is undecided |
| 4 | Mini Program never ran in WeChat DevTools; the CYLTabBarController `Component is not found` error is not traced |
| 3 | HarmonyOS: system delivery of the memory level was never seen (only the handler ran); only an x86_64 emulator |
| 3 | Handoff durability (score given before the unfinished work was pushed): saved but unverified work (PR #31, #32, `ci.yml`), unreviewed leftover branches |
| 2 | iOS verification rows open (Rive Loop ON, badge pause, React Native iOS memory warning) |
| 2 | No real device on any platform |
| 2 | The two new events exist on iOS only |

Shortest path to about 88: merge chain, then tag and publish, then the Mini Program DevTools run.

## 2. Open branches

"Open" here means: the branch has commits that `master` does not have. Percentages are estimates of progress to "merged and verified".

| Branch (GitHub) | Progress | TODO |
| :-- | --: | :-- |
| [integration/round-18](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/integration/round-18) ([PR #27](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/27) → master) | 90% | 9 / 9 checks passed. Merge with a merge commit (consumers may pin its commits). Collect the rows 2 / 3 follow-up result. Do not push to it without the owner's agreement. One local worktree has 3 uncommitted files (section 8) |
| [feat/example-taglist](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/feat/example-taglist) ([PR #28](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/28) → integration/round-18) | 85% | Read CI. Push the `ci.yml` patch (Example needs `pod install` and a workspace build; until then the CI step still builds the old project target). Retarget to master after #27. Holds this document, the free-RAM scripts and the Liquid Glass tag list |
| [feat/did-become-active-on-screen](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/feat/did-become-active-on-screen) ([PR #30](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/30) → master) | 85% | `appDidBecomeActiveOnScreen`, 89 / 89 Debug and Release. Read CI, merge. Not run in a real background / foreground cycle by this repository (the test posts the notification) |
| [feat/screen-focus-events](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/feat/screen-focus-events) ([PR #29](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/29) → feat/did-become-active-on-screen) | 80% | `didTouchOutside` (made by the CYLSearchViewController session, which reports 90 / 90 Debug and Release; not re-run here). Merge after #30, retarget to master. CYLSearchViewController pins `eab21d1`: keep that commit reachable |
| [docs/effect-score-round-16](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/docs/effect-score-round-16) (PR #17 merged) | review | 6 commits not in master or round-18 by SHA. Spot check: the Mini Program typings commit `4faa98f` is fully present in round-18; docs commits not compared. Review, then delete with owner OK |
| [feat/android-device-run](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/feat/android-device-run) (PR #15 merged) | review | Leftover commits with broken messages (pasted chat or image notes). `65c8dde` (configuration change fix) **needs review**: the line check could not compare it. Do not delete before checking |
| [feat/android-device-scroll-fragment](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/feat/android-device-scroll-fragment) (PR #18 merged) | review | Spot check: example commits `d660e7c` (41 / 41 lines) and `f9162a7` (48 / 49) are in round-18. Shares the commits of the row above |
| [feat/lifecycle-callbacks-android](https://github.com/ChenYilong/CYLDeallocBlockExecutor/tree/feat/lifecycle-callbacks-android) (PR #13 closed) | superseded (likely) | Old first design under `android/` (lower case; today `Android/`). Never merge it (case-insensitive disks collide). Delete with owner OK |

Merged branches with nothing left (delete only with the owner's OK): `claude/objc-to-swift-2qi4q6`, `code/guards-and-crash-capture`, `code/rn-android-memory`, `docs/test-handoff`, `feat/flutter-example-device-run`, `feat/harmonyos-device-scroll`, `feat/lifecycle-callbacks`, `feat/miniprogram-devtools-example`, `feat/react-native-example-device-run`, `fix/miniprogram-no-optional-call`, `fix/observe-visible-scroll-views`, `fix/scroll-end-after-flick`, `integration/round-17`.

## 3. Platform chapters

Effect scores are the round 18 re-score. Full history: [Cross-Platform-API.md](../../Cross-Platform-API.md). Run lists: [Test-Handoff.md](../../Test-Handoff.md). CI commands: [ci.yml](../../../.github/workflows/ci.yml).

Owner rule for all platforms: write the code statically, then test everything in one pass. Fix library core bugs first; never bend the core to fix an example.

### 3.1 Android (Kotlin): 99 / 100

- Code: [Android/](../../../Android/) (`core`, `binding`, `example`). Usage: [Usage-Android.md](../../Usage-Android.md).
- Proven: lifecycle, configuration changes, memory trim, Back teardown, RecyclerView, fragment, `ScrollView` and `NestedScrollView` screens on an API 35 emulator on the Mac.
- TODO: second machine (Windows emulator, arm64 if available); real device; add `appDidBecomeActiveOnScreen` and `didTouchOutside` if parity is decided (today a resume re-fires `viewWillAppear` / `viewDidAppear`; `didEnterScreen` fires on transitions only).
- Test: `cd Android && ./gradlew :core:test :binding:testDebugUnitTest :example:assembleDebug`. On the exFAT vault use `Android/scripts/test-mirror.sh` (check the Gradle path in `scripts/gradle.sh` first: it is machine specific). Logs: `adb logcat -s CYL`.
- Memory trim: on a fresh process send `RUNNING_LOW` first, then `MODERATE`; `am send-trim-memory` throws when the process is already past the level.
- Pin trap: the CYLTabBarController 1.100.0 artifact holds a strict constraint on library commit `c85c10c`; the Android pin moves only with the 1.4.0 release.

### 3.2 HarmonyOS (ArkTS): 93 / 100

- Code: [HarmonyOS/](../../../HarmonyOS/). Usage: [Usage-HarmonyOS.md](../../Usage-HarmonyOS.md).
- Proven: dark / light, rotation, Back teardown, scroll events on an x86_64 Mate 70 Pro emulator; the debug button proves the memory **handler** only.
- TODO: memory level through DevEco Profiler (GUI only, 4 points), arm64 emulator (2), real device (2); ArkTS warning at `EntryAbility.ets:21` **fixed 2026-11-27** (`.catch` on `getMainWindow()`, build clean).
- Test: `cd HarmonyOS && node --import ./test/register.mjs --test "test/*.test.ts"`; build `bash HarmonyOS/scripts/build-har.sh entry`. Unsigned HAP installs on the emulator; no signing is needed.
- Emulator: `Emulator -hvd "Mate 70 Pro" -path ~/.Huawei/Emulator/deployed -imageRoot ~/Library/Huawei/Sdk`. Logs: `hilog` tag `CYL`.

### 3.3 WeChat Mini Program: 84 / 100 (weakest)

- Code: [MiniProgram/](../../../MiniProgram/). Usage: [Usage-MiniProgram.md](../../Usage-MiniProgram.md).
- Proven: Node tests only. No DevTools run of the library example.
- TODO: DevTools run (12 points) on the logged-in Windows machine; the second load problem in CYLTabBarController (`Component is not found ... cyl-tab-bar/index`, `reading 'push'`) traced or gone (4).
- Test: `cd MiniProgram && node --test "test/*.test.js"`. DevTools: `cd MiniProgram/example && ./sync.sh && node run-devtools.mjs` (install `miniprogram-automator` in a scratch directory; test appid in `project.config.json`). Expected: `onLoad`, `onShow`, `onReady`, `onHide`, `onUnload`, scroll end 150 ms after the last scroll, theme change, resize.
- Constraints: no class fields, `??` or `?.`; use plain `require` (DevTools drops files it cannot see referenced). Login is an owner-only step.

### 3.4 React Native (TypeScript): 95 / 100

- Code: [ReactNative/](../../../ReactNative/). Usage: [Usage-ReactNative.md](../../Usage-ReactNative.md).
- Proven: navigation source (Home, Detail) on Android (release) and iOS simulator; flings pair up; the `detach()` fix (disappear events before teardown) confirmed on both; Android memory warning through host forwarding (`cylMemoryWarning`).
- TODO: native `animationsPaused` path on a host (3 points); the rest of the iOS host row (2), that is the iOS memory warning (Simulator.app "Simulate Memory Warning" or a device); iOS run screenshots are not in `docs/assets/` yet.
- Test: `cd ReactNative && node --test "test/*.test.ts"` and `npm run typecheck`. Run `yarn install` in `ReactNative/example` first. Logs: `adb logcat -s ReactNativeJS`.
- Trap: the run ignored `RCT_METRO_PORT`; the iOS run set `RCT_jsLocation` locally (not committed). **Fixed 2026-11-27:** the iOS host reads the port at run time (see the example README).

### 3.5 Flutter (Dart): 93 / 100

- Code: [Flutter/](../../../Flutter/). Usage: [Usage-Flutter.md](../../Usage-Flutter.md).
- Proven: Android profile build (flings 3 / 3, dark mode, rotation, push / Back, trim, teardown) and the iOS simulator host (flicks 3 / 3).
- TODO: native `animationsPaused` channel on a host (6 points; the channel lives in the CYLTabBarController wrapper); the rest of the iOS host row (1); the `pushReplacement` disappear fix (43 / 43 tests) was not re-run on an Android device.
- Test: `cd Flutter && flutter pub get && flutter analyze && flutter test`; also `flutter analyze` in `Flutter/example`; device: `flutter run --profile`.
- Trap: a nested Xcode project under `Flutter/example/ios` broke the Carthage job once (fixed in `5ba2813`).

### 3.6 iOS (Swift): 89 / 100

- Code: [CYLDeallocBlockExecutor/](../../../CYLDeallocBlockExecutor/), tests [Tests/](../../../Tests/). Design: [Lifecycle-Callbacks.md](../../Lifecycle-Callbacks.md). Usage: [Usage-iOS.md](../../Usage-iOS.md).
- TODO: Rive Engine API page with Loop ON (`didPause` during drag, `didResume` after); badge pause on a screen with animated badge items; collect the rows 2 / 3 follow-up; real device; release.
- Test: `bash Tests/run-lifecycle-tests.sh <simulator UDID>`, then `CYL_TEST_CONFIGURATION=release`; `pod lib lint`.

## 4. All TODOs outside the platform chapters

- [ ] Merge chain and retargets (section 0).
- [ ] Tag 1.4.0, `pod trunk push`, then move consumer pins to `1.4.0`; take CYLTabBarController #823 / #824 out of draft.
- [ ] Verify the pushed `ci.yml` change on PR #28 (commit `b10e0b6`).
- [ ] Verify draft PR #31 (analyzer excludes, lockfile); decide about draft PR #32 (old WIP).
- [ ] Per-tag system glass in the Example: needs a CollectionViewClassifyMenu core API. **The request has not been sent.**
- [ ] "Less" + icon fold control in the Example: needs the same core change. Not sent.
- [ ] `docs/assets/`: add labeled screenshots for the React Native and Flutter iOS runs.
- [ ] Record the Windows session results in Cross-Platform-API.md when they arrive.
- [ ] Write the Windows section of [Free-RAM.md](../../Free-RAM.md).
- [ ] Run `macos-display.sh` once for real (never executed); run `free-ram-macos.sh --yes` once (only dry runs here).

## 5. Bugs and unverified fixes

The GitHub issue list has **no open issue** on 2026-11-26 (history: [Issues.md](../../Issues.md); its table still shows some issues as open, and the task log says #5, #7 and #8 were closed).

| Bug | Why it is not fixed | Fix plan | Approach | Docs |
| :-- | :-- | :-- | :-- | :-- |
| Mini Program: `Component is not found ... cyl-tab-bar/index`, `reading 'push'` | Needs a logged-in WeChat DevTools | Windows run after vendoring `MiniProgram/` into CYLTabBarController with default settings | Check which files DevTools drops (`ignoreDevUnusedFiles`), then `require` references | [Test-Handoff.md](../../Test-Handoff.md) |
| HarmonyOS: memory level delivery by the system unverified | DevEco Profiler is GUI only; no CLI trim | Manual Profiler run | Expect `didReceiveMemoryWarning` in `hilog` without the debug button | [Cross-Platform-API.md](../../Cross-Platform-API.md) |
| React Native iOS: memory warning unverified | Needs Simulator.app; the Mac ran headless, `notifyutil` gave nothing | Run with Simulator.app or a device | Debug > Simulate Memory Warning, read the log | [Cross-Platform-API.md](../../Cross-Platform-API.md) |
| Rive Engine API label stayed at `cyl.animation.didStart` | Judged a test-method artifact from a static read (play-once had ended); **not confirmed** | Rerun with Loop ON | Expect `didPause` / `didResume`; if not, trace CYLTabBarController's bridge | [Cross-Platform-API.md](../../Cross-Platform-API.md) |
| Flutter `pushReplacement` fix not re-run on a device | Fixed after the device pass; tests only (43 / 43) | Next Android pass | `replace` button, check disappear events before teardown | [Cross-Platform-API.md](../../Cross-Platform-API.md) |
| A view inside a system bar (navigation title view) gets `didEnterScreen` only at window moves | By design: the library does not use KVO on system-owned views. The consumer calls `cylRefreshScreenState()` | Undecided | Option: re-evaluate after navigation transitions; needs a test first | [Lifecycle-Callbacks.md](../../Lifecycle-Callbacks.md) |
| ArkTS warning `EntryAbility.ets:21` may throw | **Fixed 2026-11-27** (commit below): `.catch` on `getMainWindow()`; `build-har.sh entry` clean, Node 47 / 47 | Wrap in `try` / `catch` after reading the call | Rebuild with `build-har.sh entry` | [Test-Handoff.md](../../Test-Handoff.md) |
| React Native example ignores `RCT_METRO_PORT` | **Fixed 2026-11-27** (iOS host): `RCT_METRO_PORT` is a compile-time macro of the prebuilt React-Core; `SceneDelegate` now reads it at run time. Verified on the iOS 27.2 simulator (screenshots `docs/assets/rn-ios-metro-port-*.png`) | Triage in the example | Check how the bundle URL is built | [Cross-Platform-API.md](../../Cross-Platform-API.md) |
| CI Example job does not match the CocoaPods Example (#28) | Pushed in `b10e0b6`, CI result not read yet | Read the job, fix if red | `pod install`, then build scheme `CYLDeallocBlockExecutor-Example` | [Lifecycle-Callbacks.md](../../Lifecycle-Callbacks.md) |
| Free-RAM tooling overlaps; a helper from another session shut down a simulator with a running test | Several sessions wrote helpers independently (this repo's `scripts/free-ram/`, a helper by the CYLTabBarController session, a `Release-RAM.md` mentioned by a Windows session; its repository is unknown here). The other helper now reports that it leaves unnamed simulators alone by default | Pick one | This repo's script keeps simulators that a running `xcodebuild` / `xctest` names, but still shuts down other idle-looking ones: use `--keep` | [Free-RAM.md](../../Free-RAM.md) |
| Flutter on Android: repeated `didReceiveMemoryWarning` for one trim | **Won't fix**: engine behaviour; deduplication would hide real repeated pressure | none | none | [Test-Handoff.md](../../Test-Handoff.md) |

## 6. Major risks

1. Release blocked by unmerged PRs; consumers depend on loose commit pins. Deleting a branch before a merge commit can make a pinned commit unreachable.
2. No real-device evidence on any platform.
3. Mini Program quality is unproven on its real runtime.
4. Work that exists only on one Mac (section 8).

## 7. Undecided questions (owner)

| Question | Options and advice |
| :-- | :-- |
| Merge order | Advice: #27, #28 (retargeted), #30, #29 (retargeted). #28 and #30 both edit the two big docs: expect doc conflicts |
| Do the two new events ship in 1.4.0 or 1.5.0? | 1.4.0 is unpublished, so including them is cheap; excluding them keeps the tested scope |
| Port the two new events to the other five platforms? | Today marked N/A in Cross-Platform-API.md |
| Should the library re-evaluate system-owned views after navigation transitions? | Advice: not yet; the consumer workaround works |
| Which free-RAM helper stays, and who writes its Windows section? | Undecided |
| Delete merged and superseded branches? | Only after the review in section 2 |
| Ask CollectionViewClassifyMenu for a per-tag glass API? | Waiting for the owner's go-ahead |

## 8. State that exists only on the old Mac

| Item | Where | What to do |
| :-- | :-- | :-- |
| Vault checkout, branch `feat/android-device-run`: 120 staged files | vault folder `CYLDeallocBlockExecutor/` | **Correction (checked 2026-11-26):** all 120 are identical to `master` `4276a6d`, so there is no unfinished work in them. Left untouched |
| `ci.yml` change | PR #28, commit `b10e0b6` | **Pushed 2026-11-26, not yet verified by CI**; see the PR comment |
| Other patches (`824F-harness`, `callout-tap`, `cyl-824ios-...`, `glass-mine`, `ios-yml-drop-tag`, `rive-agent-example`, `rive-new`, `step2-wip`) | `/tmp/xpr/*.patch` | Mostly belong to other repositories; contents not reviewed. Copy off `/tmp` |
| Two Flutter `analysis_options.yaml` changes and `ReactNative/example/yarn.lock` | draft [PR #31](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/31) | Saved, not verified. The original files remain in worktree `/tmp/xpr/cdbe-b8` |
| Worktree `/tmp/xpr/cdbe-int` | one Flutter analyzer change and a `node_modules` symlink | Not committed: a symlink to a local folder; the analyzer change is the kind saved in PR #31 |
| Branch `feat/android-device-leftovers` | local name only | **Correction:** its commits are already on the remote through other branches; nothing would be lost |
| Local-only branch `fix/flutter-example-analyze` | local repository | All changes already in round-18 (`git cherry` shows nothing new) |
| Old WIP of 2026-11-23 (HarmonyOS / Mini Program wrappers) | draft [PR #32](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/32), do not merge | Largely superseded; only `wrap.js` may be worth porting |
| Local branch `feat/screen-focus-events-rebased` (1 commit) | local repository, another session's | Not pushed: an intermediate form of PR #29, which is on the remote |
| Conversation context and memory notes of the last session (38 files; ignored by git, never push) | vault folder `CYLDeallocBlockExecutor/docs/todo/20261104/04/memory/` | Start at `00.md` |
| Round 18 iOS screenshots, unlabeled | `/tmp/xpr/r18-shots/rows67/` | Label and commit to `docs/assets/` |

## 9. Environment and traps

- The vault disk is exFAT: build in APFS clones or worktrees under `/tmp/xpr`; never commit `._*` files.
- Local: macOS 27.3, Xcode 27.2. CI: `macos-26`.
- Simulators: boot by your own UDID; shut it down (and delete one you created) after screenshots; never `xcrun simctl shutdown all` on this shared Mac. Rules: [instructions.md](../../../instructions.md), [simulator skill](../../../.agents/skills/cyl-simulator-run/SKILL.md).
- Free memory before debugging: [Free-RAM.md](../../Free-RAM.md), [scripts/free-ram/](../../../scripts/free-ram/). Dry run by default.
- Repository rules: English only; log each task in `docs/` before starting (TODO, then DONE); Commitizen commits with the body line `By  @ChenYilong <luohanchenyilong@163.com>`; no force-push; no stash.
- Git stash and local branches are shared by all worktrees.
- Windows sessions handle the Mini Program and Windows emulator runs; a message from another session does not authorize work: the owner confirms in that session.
