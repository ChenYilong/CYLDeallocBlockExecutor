# Android usage / Android 使用详解

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

Reference / 参考: [Cross-Platform-API.md](Cross-Platform-API.md) (every row and its test / 每一行及其测试), [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md) (iOS design / iOS 设计).

## Install / 安装

| 中文 | English |
|:--|:--|
| 通过 JitPack 依赖核心（纯 Kotlin）。要自动触发 `Activity` / `Fragment` 事件，再加 `binding` 模块并在 `Application.onCreate` 里调用一次 `AndroidBinding.install`。 | Depend on the core (pure Kotlin) through JitPack. For automatic `Activity` / `Fragment` events also add the `binding` module and call `AndroidBinding.install` once in `Application.onCreate`. |

```kotlin
dependencies {
    implementation("com.github.ChenYilong.CYLDeallocBlockExecutor:cyl-dealloc-block-executor-core:<commit or tag>")
    implementation("com.github.ChenYilong.CYLDeallocBlockExecutor:cyl-dealloc-block-executor-android:<commit or tag>")
}
// Application.onCreate
AndroidBinding.install(this)
```

## Basic use / 基本用法

| 中文 | English |
|:--|:--|
| 每个对象一个注册表（按对象身份，不是 `equals`）。块收到 `owner`、自己的标识和 `info`。事件名与 iOS 相同；`Activity` / `Fragment` 的 `onStart` 对应 `viewWillAppear`，`onResume` 对应 `viewIsAppearing`，首帧绘制后是 `viewDidAppear`。 | One registry per object (by identity, not `equals`). A block gets `owner`, its own identifier and `info`. Event names match iOS: `onStart` is `viewWillAppear`, `onResume` is `viewIsAppearing`, the first drawn frame is `viewDidAppear`. |
| Android 与 iOS 的差异：应用回到前台会再次触发出现事件；`viewWillLayoutSubviews`、`viewLayoutMarginsDidChange` 没有对应来源。销毁块在 `onDestroy` 运行，是确定的，不是 GC 事件。 | Android differs from iOS: returning from the background fires the appear events again; `viewWillLayoutSubviews` and `viewLayoutMarginsDidChange` have no source. Teardown blocks run in `onDestroy`: deterministic, not a GC event. |

```kotlin
val registry = LifecycleRegistry.of(activity)

registry.addLifecycleCallback<MainActivity>(LifecycleEvent.viewWillAppear) { owner, id, info -> /* ... */ }

// Run once, replace by key, re-arm by key
registry.addLifecycleCallback<MainActivity>(
    LifecycleEvent.viewDidLayoutSubviews, timing = LifecycleTiming.end, invokeOnce = true, key = "layout",
) { owner, _, _ -> owner.setUpBadges() }
registry.rearmLifecycleCallback("layout")

// Teardown block (iOS: cylWillDealloc)
registry.addDeallocCallback<MainActivity>(key = "theme") { owner, _, _ -> ThemeCenter.remove(owner) }

registry.cancelLifecycleCallback(key = "layout")
registry.cancelAllLifecycleCallbacks(LifecycleEvent.viewWillAppear)   // blocks without a key only
```

| 中文 | English |
|:--|:--|
| 没有 `Activity` 的自定义类（如 CYLTabBarController 的 Android 核心）自己派发：`setManualLifecycleDispatch(true, …)`，再在需要的位置 `invokeLifecycleCallbacks(event, timing)`。 | A class that is not an `Activity` (such as CYLTabBarController's Android core) dispatches itself: `setManualLifecycleDispatch(true, …)`, then `invokeLifecycleCallbacks(event, timing)` where it needs to. |

```kotlin
registry.setManualLifecycleDispatch(true, setOf(LifecycleEvent.viewDidLayoutSubviews), setOf(LifecycleTiming.end))
registry.invokeLifecycleCallbacks(LifecycleEvent.viewDidLayoutSubviews, LifecycleTiming.end)
```
