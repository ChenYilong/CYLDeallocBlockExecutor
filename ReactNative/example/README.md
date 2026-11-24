# React Native device check app

`App.tsx` mounts the library's React Native sources (`../src`, not a published package) on a `FlatList` of 400 rows. A block per
`LifecycleEvent` logs `CYL EVENT n name` and `LifecycleCenter.whileUserScrolls` logs `CYL SCROLLCOUNT pauses=… resumes=…`
(read with `adb logcat -s ReactNativeJS`). The `replace` button unmounts the list screen, which runs the teardown block.

Android release build (the JavaScript is bundled, no Metro needed), in a copy on APFS if the checkout is on exFAT:

```sh
cd ReactNative/example && yarn install        # or npm install
cd android && ./gradlew :app:assembleRelease -PreactNativeArchitectures=arm64-v8a
```

JDK 17, `ANDROID_HOME`, NDK 27.1.12297006 and build-tools 37.0.0. Android only: there is no `ios/` folder.
