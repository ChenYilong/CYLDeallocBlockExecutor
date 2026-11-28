> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Cross-platform matrix (library code as read)
"none" means the library has no automatic source; an app can still dispatch the event by hand.

## Automatic source per event group
| Events | iOS | Android | Flutter | HarmonyOS | React Native | Mini Program |
|---|---|---|---|---|---|---|
| load, parent moves | method hooks | create / attach / destroy | initState, activate, deactivate | aboutToAppear / aboutToDisappear | mount / unmount | onLoad / onUnload |
| appear, disappear | method hooks | start, resume, drawn, pause, stop | RouteObserver + route animation | onPageShow / onPageHide | React Navigation events | onShow / onReady / onHide |
| will-layout | hook | none | layoutLifecycle | none | none | none |
| did-layout | hook | global layout | layoutLifecycle | onAreaChange | onLayout | none |
| safe-area insets | hook | rootWindowInsets | metrics observer | avoid area | injected source | none |
| layout margins | hook | none | none | none | none | none |
| size transition | hook | configuration | metrics observer | onAreaChange | Dimensions | onResize |
| traits / theme | hook | configuration (night, font) | brightness, text scale | color mode | Appearance, font scale | themeChanged (forwarded by app) |
| memory warning | hook | onTrimMemory, onLowMemory | didHaveMemoryPressure | onMemoryLevel | AppState (iOS) or host event | memoryWarning (forwarded by app) |
| window moves | UIView hooks | observeWindow | none | windowAttached / Detached | none | onLoad / onUnload |
| enter / leave screen | VC appear + view visibility | appear + observeVisibility | appear + setScreenVisible | appear + visibleAreaChanged | appear + setScreenVisible | appear + screenVisible, observeScreen |
| app active while on screen | yes | not in enum | not in enum | not in enum | not in enum | not in enum |

On Android the stock binding delivers configuration and memory changes to **Activities** only, and layout and insets only for Activities; Fragments need manual controller calls.

## Scroll detection
| Platform | Begin | Drag end | Final end |
|---|---|---|---|
| iOS | pan gesture | zero-delay timer reads isDecelerating | 60 Hz poll |
| Android RecyclerView | DRAGGING | SETTLING or IDLE | IDLE |
| Android other views | first scroll change | 150 ms quiet, no deceleration | same moment |
| Flutter | start with drag details | first update without drag details | end notification |
| React Native | onScrollBeginDrag | onScrollEndDrag (velocity) | momentum end, or at once |
| HarmonyOS | onScrollStart | onScrollStop | same moment |
| Mini Program | first onPageScroll | 150 ms quiet | same moment |

## Behaviour differences
| Topic | Difference |
|---|---|
| Return from background | Android fires appear events again; iOS, Flutter and React Native do not feed appear events from app state |
| Key spaces | iOS: lifecycle (with custom) and dealloc. Ports: lifecycle, custom, dealloc |
| isAnimated on appear | iOS passes the real flag; Flutter derives it from transition duration; RN true in stack mode; HarmonyOS and Mini Program false; the Android controller leaves the default false |
| Center dispatch | Ports skip an observer cancelled during the same dispatch; iOS does not check (finding F8) |
| Locking | iOS and Android lock; Dart and JS do not |
| Owner reference | iOS unretained; Android, Flutter, HarmonyOS and RN weak; Mini Program weak only when WeakRef exists |
