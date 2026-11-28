> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Configuration and project files

## Versions
| Item | Value |
|---|---|
| Library version | 1.4.0 in podspec, Android default, Flutter, HarmonyOS, React Native, Mini Program; 1.3.0 is the latest git tag |
| Android library | compileSdk 34, minSdk 21, Gradle wrapper 8.14.3 |
| Android example | compileSdk / targetSdk 35, Java 17 |
| Flutter example | AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1, 8G Gradle heap |
| React Native example | RN 0.88.0, React 19.3.0, Node 22+, compileSdk 37, target 36, minSdk 24, NDK 27.1.12297006, Kotlin 2.2.0, Gradle 9.4.1, Hermes, new architecture |
| HarmonyOS | target 6.0.1(21), compatible 5.0.0(12), hvigor model 6.0.1, signingConfigs empty, phone and tablet |
| Mini Program example | appid touristappid (override with CYL_APPID), libVersion latest, es6 / enhance / minified off, dark mode with theme.json |
| TypeScript | strict, noEmit, erasableSyntaxOnly, bundler resolution |

## Xcode project facts (extracted from project.pbxproj by pattern; the files were not read in full)
| Project | Targets | iOS deployment target |
|---|---|---|
| CYLDeallocBlockExecutor.xcodeproj | CYLDeallocBlockExecutor-Framework, CYLDeallocBlockExecutor | 15.0 |
| CYLTabBarControllerTestDemo/TestDemo.xcodeproj | TestDemo | 9.3 |
| Flutter/example/ios/Runner.xcodeproj | RunnerTests, Runner | 15.0 |
| ReactNative/example/ios/CylDeallocExample.xcodeproj | CylDeallocExample | 15.1 |

The library project lists all 8 library Swift files in its sources. Shared scheme CYLDeallocBlockExecutor-Framework exists for Carthage. The TestDemo project file says 9.3, while its Podfile sets 15.0.

## Manifests and host settings
- Android binding main manifest is empty; its debug manifest declares only the Robolectric HostActivity.
- React Native Android host: singleTask activity with configChanges; the release build is signed with the template debug key (demo only).
- React Native iOS and Flutter iOS hosts use scene delegates. The Flutter example turns Swift Package Manager off because the package reference broke carthage build when it scanned the repo.
- iOS Example Info.plist names CYLExampleSceneDelegate.
- An xcworkspace file in the library project holds an absolute path from an old checkout location (harmless leftover) [read].

## Leftovers
Personal xcuserdata folders for three user names are tracked. Other leftovers are listed in F13.
