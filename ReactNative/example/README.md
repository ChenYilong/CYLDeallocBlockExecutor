# React Native device check app

`App.tsx` mounts the library's React Native sources (`../src`, not a published package) on a `FlatList` of 400 rows. A block per
`LifecycleEvent` logs `CYL EVENT n name` and `LifecycleCenter.whileUserScrolls` logs `CYL SCROLLCOUNT pauses=… resumes=…`
(read with `adb logcat -s ReactNativeJS`). The `replace` button unmounts the whole navigator, which runs the teardown blocks.

## Navigation source (appear and disappear)

The app is a React Navigation native stack (`@react-navigation/native`, `@react-navigation/native-stack`, `react-native-screens`, `react-native-safe-area-context`; autolinking picks the native parts up) with two screens: Home (the list) and Detail. Each screen passes its `navigation` object to `useLifecycle(owner, { navigation, navigationMode: 'stack' })`; `focus`, `blur`, `transitionStart` and `transitionEnd` then fire `viewWillAppear`, `viewIsAppearing`, `viewDidAppear`, `viewWillDisappear`, `viewDidDisappear`, and `didEnterScreen` / `didLeaveScreen` follow the did events. Lines read `CYL EVENT n name screen=Home|Detail`.

Test (written statically, not run yet): launch, then `push Detail`, then `Back`. Expect on Home: `viewWillAppear`, `viewIsAppearing`, `viewDidAppear`, `didEnterScreen` after launch; after the push Home logs `viewWillDisappear`, `viewDidDisappear`, `didLeaveScreen` and Detail logs the appear four; after Back Detail logs the disappear three then `CYL EVENT teardown screen=Detail`, and Home logs the appear four again.

Android release build (the JavaScript is bundled, no Metro needed), in a copy on APFS if the checkout is on exFAT:

```sh
cd ReactNative/example && yarn install        # or npm install
cd android && ./gradlew :app:assembleRelease -PreactNativeArchitectures=arm64-v8a
```

JDK 17, `ANDROID_HOME`, NDK 27.1.12297006 and build-tools 37.0.0. Android only: there is no `ios/` folder.

## Memory warning on Android

`AppState` `memoryWarning` exists on iOS only. On Android the host forwards `onTrimMemory` as the device event
`cylMemoryWarning` (`MEMORY_WARNING_EVENT`); the library subscribes to it only when `Platform.OS` is not `ios` (through
`PlatformSources.hostEvents`, which `createNativeSources` fills with `DeviceEventEmitter`), so one warning is never delivered
twice. `MainApplication.kt` in this app shows the forwarding:

```kotlin
override fun onTrimMemory(level: Int) {
  super.onTrimMemory(level)
  if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW && level != ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
    reactHost.currentReactContext
      ?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      ?.emit("cylMemoryWarning", null)
  }
}
```

Without the forwarding the event stays unfired (a missing source). Written statically: it has not been built or run yet
(test: `adb shell am send-trim-memory <package> RUNNING_LOW` after Home, look for `didReceiveMemoryWarning` in the log).
