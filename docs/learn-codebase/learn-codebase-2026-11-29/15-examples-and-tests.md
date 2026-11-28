> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Example apps and test harnesses (read in full)

## Android
**Example app** (compileSdk 35, minSdk 21; ExampleApp calls AndroidBinding.install):
- MainActivity: registers every LifecycleEvent **before super.onCreate**, because viewDidLoad fires from onActivityCreated inside it. It leaves "...Subviews" events off the on-screen log to avoid a layout loop. Buttons open the other screens. SecondActivity is a plain Activity.
- ListActivity: a fragment with a 400-row RecyclerView; the fragment adds blocks in onAttach before super; observeScrolling is stopped in onDestroyView; whileUserScrolls counts pauses and resumes.
- ScrollActivity / NestedScrollActivity: 300 rows; observeScrolling is posted so the view is attached, and stopped in onDestroy.
- All but SecondActivity declare configChanges, so rotation and dark mode do not recreate them.
- The whileUserScrolls closures capture the activity and are not cancelled, only replaced by the next screen (demo only) [read].

**Tests:** core registry (identity ownership, thread-safety with 8 x 200 adds), controller (timings, pending flush, insets, config, teardown once), observable moments and log; binding tests run on Robolectric SDK 34. They reach RecyclerView.setScrollState and ViewTreeObserver.dispatchOnScrollChanged by reflection, and mimic device ordering by calling the Application callback before activity resources change.

## Flutter
**Example** (path dependency on the package, Dart sdk ^3.13.7): one page with a 400-row list, layoutLifecycle around scrollLifecycle, blocks for every event added before super.initState, push and replace buttons, global pause / resume counters. Layout-event blocks only log. Android and iOS hosts are the template; RunnerTests is empty and the README is template text.

**Tests:** mixin (timings bracket super; no appear events from app background; push / pop; layout order; brightness, text scale, size, padding; memory; teardown once with a mounted owner; lazy observer; GlobalKey reparent; pushReplacement order), registry, observable.

## HarmonyOS
**Demo:** registers 18 event names (didEnterScreen and didLeaveScreen are not among them) and a teardown block, passes the initial color mode, hooks memory and color callbacks through static fields on EntryAbility, attaches the window if available, feeds a 120-row List's onScrollStart / onScrollStop, and passes the new size twice to onAreaChange. Buttons: Close, Dark, Light, Land, Port, simulate memory level.

**Tests:** run on Node against the module sources through a resolve hook that adds .ts. Registry, controller, observable.

## React Native and Mini Program
See 06 and 07.

## iOS demos
- Example: scene-based app. A UIView.themeMap extension pairs the theme observer with a keyed teardown block. ViewController uses viewWillAppear, a run-once .end layout block and a trait block, then registers 300,000 dealloc blocks on a temporary object as a stress demo. See F17.
- CYLTabBarControllerTestDemo: a login screen and a two-tab CYLTabBarController subclass, pulling CYLTabBarController by commit through CocoaPods (iOS 15). Its tracked code does not use this library (F13).

## iOS test app
Tests/LifecycleTests/main.swift is one file with numbered sections and a check() helper; see 10-tests-catalog.md.
