> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Findings
Line numbers are at 505d187. Nothing here has been fixed.

**Revision (same day, after reading all docs, tests and examples):** F1 was demoted from a bug to a comment issue. F7 is now the documented iOS capture rule applied to Android. F3, F5, F6, F9, F10 and F12 were narrowed. F13 grew, and F15 to F17 are new.

## Summary
| ID | Platforms | Finding | Evidence (none reviewed by the maintainer) |
|---|---|---|---|
| F1 | all ports | Registry comment overstates cancel during teardown (behaviour matches the iOS doc) | reproduced on Mini Program only [probe]; other ports read only, not reproduced |
| F2 | MP (probe); other ports (read) | Teardown mid-scroll leaves pause without resume | reproduced on Mini Program only [probe]; other ports read only, not reproduced |
| F3 | Mini Program | Docstring and typings name the wrong property | reproduced [probe]; the rest read only |
| F4 | Android | observeWindow and observeVisibility stack listeners | read only, not reproduced |
| F5 | Android | Pending appear survives stop(); viewDidAppear can come last | read only, not reproduced |
| F6 | Android | Quick pause can still send didEnterScreen (low) | read only, not reproduced |
| F7 | Android | Capture rule applies and is missing from the Android doc | read only, not reproduced |
| F8 | iOS | Cancelled global observer still runs in the same dispatch | read only, not reproduced |
| F9 | HarmonyOS | Bridge order wrong if removed without onPageHide | read only, not reproduced |
| F10 | HarmonyOS | Window px and component vp may mix | unverified guess, not reproduced |
| F11 | React Native | Unstable options remount the controller and use up teardown blocks | read only, not reproduced |
| F12 | Android, RN | Memory-trim threshold; handoff test risk | read only, not reproduced |
| F13 | docs and leftovers | Drift table | read only, not reproduced |
| F14 | iOS test script | A failed launch may skip the missing-result report | read only, not reproduced |
| F15 | React Native docs | Snippet misses load events and may double-add under StrictMode | read only, not reproduced |
| F16 | Flutter, RN docs | Install lines: stale branch; no root package.json | read only, not reproduced |
| F17 | iOS Example | Reads ivar during dealloc; missing super | read only, not reproduced |

## F1. A registry comment overstates cancel during teardown
**Revised: first reported as a bug. It is a code-comment and test-coverage issue.**
- `docs/Usage-iOS.md:35` says that once destruction has started, a block can no longer be cancelled. The ports behave the same way as that documented iOS rule.
- The ports' registry comment ("blocks run in identifier order from a snapshot, so a block can add or cancel blocks", for example `MiniProgram/registry.js:18`) names no exception for teardown. It holds for lifecycle and custom blocks, not for teardown blocks.
- Cause: runDealloc removes the dealloc entries before running the snapshot (`MiniProgram/registry.js:236`, `ReactNative/src/registry.ts:261`, `HarmonyOS/cyldeallocblockexecutor/src/main/ets/registry.ts:261`, `LifecycleRegistry.kt:211-224`, `lifecycle_registry.dart:280-297`).
- Observed: `probes/probe-teardown-cancel.js` (Mini Program): cancel-one returns false and the later block still runs.
- Suggested change: say in the comments and port docs that teardown blocks cannot be cancelled once teardown has started. Changing the behaviour would be a design decision.

## F2. Teardown mid-scroll leaves an unmatched pause
- Where: `MiniProgram/controller.js:119` and `MiniProgram/controller.js:87` (the timer is cleared and no end is sent). Controllers on the other ports also have no end-on-teardown step.
- Reproduce: `probes/probe-unload-midscroll.js`. whileUserScrolls received pause and no resume; isUserScrolling stayed true while the controller was held.
- Note: silence from the detached **owner** is intended and tested; the global pause / resume pair is the problem.
- How long isUserScrolling stays true depends on garbage collection; without WeakRef the Mini Program holds the owner strongly [read].
- iOS: a scroll view released mid-deceleration also sends no end [read].

## F3. withLifecycle docstring and typings name the wrong property
- The code sets `cylController` (`MiniProgram/controller.js:162`), and `README.md:112` and `docs/Usage-MiniProgram.md:26` use that name correctly.
- Only the docstring (`MiniProgram/controller.js:157`) and the typings say `cyl`.
- The typings also claim `Component({...})` wrapping (`MiniProgram/typings/controller.d.ts:34`); the code and `Usage-MiniProgram.md:18` say Component lifetimes are not wrapped.

## F4. Android observers stack
- `AndroidBinding.kt:56-65`: the comment says an earlier observation is replaced, but each call adds a listener. `val key = Any()` and `key.hashCode()` do nothing.
- `observeVisibility` (`:72-96`) adds listeners on each call too, and neither returns a stop function.
- Effect: repeated calls (for example on rebind) give duplicate window events and growing listener lists.

## F5. A pending appear survives stop(), so destroy() can send viewDidAppear after viewDidDisappear
- The flush itself is intended: test `pendingDidEventsFlushOnDestroy` (`LifecycleControllerTest.kt:63-68`: start, pause, destroy) expects viewDidAppear, then viewDidDisappear.
- Not covered by that test: `stop()` runs before `destroy()`. Neither `pause()` nor `stop()` clears `appearPending`, so if `resumedAndDrawn()` never ran (a very quick close, or started and stopped without resuming), the order is viewDidDisappear first and **viewDidAppear later, in destroy()**, without didEnterScreen. Through `AndroidBinding`, onStop comes before onDestroy, so this is the binding's path.
- When the controller is called directly and an on-screen owner is destroyed without stop(), `destroyed` is already true, so didLeaveScreen is skipped (`screenVisible`).
- [read], not reproduced.

## F6. A quick pause can be followed by viewDidAppear and didEnterScreen
- The binding posts `resumedAndDrawn()` (`AndroidBinding.kt:149-155, 188`); it checks only `appearPending`.
- viewDidAppear after viewWillDisappear matches the intended flush order in `LifecycleControllerTest.kt:63-68`. The open point is narrower: if the post runs after pause(), it also sends **didEnterScreen** for an owner that is leaving. didLeaveScreen follows at stop().
- Low severity. [read], not reproduced.

## F7. The "use owner, do not capture" rule also applies on Android, and the Android usage doc does not say so
**Revised: this is the documented iOS rule applied to Android, not a separate design defect.**
- `docs/Lifecycle-Callbacks.md:282`: a stored block that captures its owner is a retain cycle; use the `owner` parameter.
- On Android the effect comes from the static map (`LifecycleRegistry.kt:36`): it keeps every registry and its blocks reachable until the owner is collected (`:41-42`), and runDealloc removes only teardown entries (`:215`). A lifecycle or custom block that captures its owner therefore keeps it reachable, even after destroy().
- `docs/Cross-Platform-API.md:32`: the round 7 leak check looked only at the owner reference. `docs/Usage-Android.md` does not warn about captures.
- [read], not measured with a heap dump. Suggested change: add the rule to the Android doc, or clear lifecycle entries on destroy.

## F8. iOS center dispatch ignores mid-dispatch cancel
- `CYLLifecycleCenter.swift:152-164` loops over the filtered list without checking membership.
- Android (`LifecycleCenter.kt:123`), Flutter (`lifecycle_center.dart:179`) and the TS / JS centers skip an entry removed in the meantime.
- Effect: an observer cancelled or replaced by an earlier observer in the same dispatch still runs once on iOS. The per-owner path does check (`CYLLifecycle.swift:359`).

## F9. HarmonyOS bridge: wrong order when a component is removed without onPageHide
- `CYLLifecycleBridge.ets:108-111` calls detachWindow before controller.aboutToDisappear. With a window attached, windowDetached calls setScreenVisible(false) (`controller.ts:69-73`). The controller's own aboutToDisappear would have run onPageHide first (`controller.ts:127-134`).
- Affects only a still-shown component that disappears **without** onPageHide having run. In the device run, Close gave the disappear events before the window moves (`Cross-Platform-API.md:122`), because onPageHide ran first.
- No device run could have shown a didLeaveScreen order problem: the demo does not register didEnterScreen or didLeaveScreen (`HarmonyOS/entry/src/main/ets/pages/Index.ets:24-27`).
- [read].

## F10. HarmonyOS size units
- The `windowSizeChange` listener (`CYLLifecycleBridge.ets:75-78`) and the component's `onAreaChange` feed the same last-size field. Window sizes are normally px and component areas vp.
- **Consistent with the device log, not proven:** each rotation logged viewWillTransition twice (`Cross-Platform-API.md:122`). Log the two sizes on a device to confirm.

## F11. React Native effect dependencies
- `ReactNative/src/native.ts:47` compares navigation and safeAreaInsets by identity.
- An object created inline changes every render: each re-render detaches and reattaches, the move events fire again, and the first re-render runs the teardown blocks while the component is still mounted.
- The example passes only the stable navigation prop. React was not run. Fix by documenting stable references or holding the sources in refs.

## F12. Memory-trim threshold, and a risk in the handoff test plan
- `ReactNative/example/android/app/src/main/java/com/chenyilong/cyldeallocblockexecutor/rnexample/MainApplication.kt:34` forwards from RUNNING_LOW; its comment says it is the same rule as the Android binding, which requires RUNNING_CRITICAL (`AndroidBinding.kt:210`).
- `AndroidBindingTest.kt:97-109` shows RUNNING_MODERATE and UI_HIDDEN fire nothing; RUNNING_LOW is also below the binding's threshold.
- `Cross-Platform-API.md:128` and `:228` report that RUNNING_LOW produced didReceiveMemoryWarning on the stock Android list screen. The threshold has been RUNNING_CRITICAL since the binding was first committed (f0beae0, 2026-11-22; git history), before those runs, so a later code change does not explain the report. Under this code, an onTrimMemory call at RUNNING_LOW fires nothing. Another delivery (a higher level the system sent after Home, or onLowMemory) is a possible explanation, not verified. (The send-order note at `:274` belongs to a Flutter trim run; it only records that `am send-trim-memory` needs RUNNING_LOW sent before MODERATE.)
- **Test-plan risk:** the RUNNING_LOW step of handoff row 7 may show nothing through the binding. Log `info.trimLevel` during that run.

## F13. Docs, comments and leftovers that disagree
| Where | Problem |
|---|---|
| `ReactNative/src/controller.ts:38` | lists beforeRemove (never subscribed) and omits blur (subscribed) |
| `ReactNative/example/README.md:20` | says there is no ios/ folder |
| `ReactNative/example/README.md:11, :40` | says the navigation and memory tests have not run; later rounds report Android runs |
| `docs/Usage-ReactNative.md:22` | omits the Android cylMemoryWarning forwarding |
| `docs/Usage-HarmonyOS.md:12` | "never built with hvigor": stale since round 13 |
| `docs/Cross-Platform-API.md:91` | "HarmonyOS/src only" and never run: stale since round 13 |
| `docs/Cross-Platform-API.md:64` | "on Android the source is never subscribed": stale since round 17 |
| `docs/Cross-Platform-API.md:73` | appDidBecomeActiveOnScreen row says "N/A: not implemented", which is not a platform reason (rule 2) |
| `docs/Cross-Platform-API.md` score | line 11 counts 41 rows (205 cells); the two tables now have 42 rows (24 + 18), likely because the 11-26 appDidBecomeActiveOnScreen row was not added to the count |
| `docs/Cross-Platform-API.md:86`, `docs/Usage-MiniProgram.md:18` | omit onPageScroll from the wrapped hooks |
| `docs/Issues.md:24, 26, 27` | list #5, #7, #8 as open; `Lifecycle-Callbacks.md:52` says they were closed (live state not checked) |
| `docs/Test-Handoff.md` | expects 85 iOS checks; the later task log records 89 / 89 after appDidBecomeActiveOnScreen |
| `README.md:153` | says CYLTabBarControllerTestDemo shows KVO without a flag; its tracked Swift files and Podfile have no observer, no cylWillDealloc and no dependency on this library |
| `LICENSE`, `HarmonyOS/cyldeallocblockexecutor/LICENSE` | copyright line names CYLTabBarController and links CYLTableViewPlaceHolder |
| `.github/workflows/ci.yml:105`, `jitpack.yml:2` | "written without a CI run" / "not run yet"; `Cross-Platform-API.md:162-167, 233` report CI and JitPack runs |
| `Android/core/.../LifecycleController.kt:23-25` (also `Cross-Platform-API.md:102`) | refer to a `detach()` that does not exist |
| `HarmonyOS/package.json:7` | main is src/index.ts, which does not exist |
| `ReactNative/example/android/app/src/main/res/raw/cyl_keep.xml:2`, `ReactNative/example/android/gradle.properties:50` | comments about other projects |
| `Flutter/example/README.md` | untouched project template text |

## F14. Test script exit path
- `Tests/run-lifecycle-tests.sh:4` sets pipefail with -e. If `simctl launch` at `Tests/run-lifecycle-tests.sh:45` or the line above returns non-zero, the script exits before report_missing_result can print the crash report. Whether simctl returns non-zero when the app dies was not checked.

## F15. React Native usage snippet: block order and StrictMode
- `useLifecycle` attaches the controller in its own effect (`ReactNative/src/native.ts:39-47`, `ReactNative/src/controller.ts:124-131`). The snippet in `docs/Usage-ReactNative.md:29-38` adds blocks in a **later** effect, so viewDidLoad and the parent-move events have already fired for a block added that way.
- The snippet's viewWillAppear block has no key and the effect has no cleanup. detach() removes only teardown blocks, so under StrictMode's double mount in development the block is likely added twice.
- [read]; React was not run.

## F16. Install instructions point at a stale branch, and the React Native form cannot resolve
- `docs/Usage-Flutter.md:20` and `docs/Usage-ReactNative.md:15` use `feat/lifecycle-callbacks`, which is 63 commits behind this HEAD (local remote-tracking ref).
- The React Native line installs the repository root through `github:`, but the root has no package.json; the package is in `ReactNative/`.
- [read]; no install was tried.

## F17. iOS Example app
- `Example/ViewController.swift:30` reads a stored property through the unretained owner during dealloc. The code comment says the ivars are already torn down; `Lifecycle-Callbacks.md:291` says never to read them that way. It reads like an old demonstration, but it is unsafe to copy.
- `Example/ViewController.swift:81-86` overrides didReceiveMemoryWarning without calling super, so a library block for that event would never fire for this class.
- [read]; not run.

## Not a finding
The ports not having appDidBecomeActiveOnScreen is not treated as a defect here: the docs record it as not implemented there [doc]. How the table scores those cells is a separate point (F13).

## Suggested order
1. F2 (unmatched pause).
2. F8 (iOS, the reference, differs from every port).
3. F11 (teardown blocks can run while the component is mounted).
4. F4, then F5 with F6 (same flag).
5. F9, after checking F10 on a device.
6. Docs and comments: F16, F15, F13, F3, F1, F7, F12.
7. F14, F17.
