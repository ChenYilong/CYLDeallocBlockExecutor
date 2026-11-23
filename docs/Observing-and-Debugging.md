# Observing moments and debugging / 监听时机与调试

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

Reference / 参考: [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md) (design v5 / 设计 v5), [Cross-Platform-API.md](Cross-Platform-API.md) (every platform / 各平台).

## What you can observe / 能监听什么

| 中文 | English |
|:--|:--|
| 任意对象的 15 个 `UIViewController` 事件，以及窗口移动、出现 / 移出屏幕、滚动（开始拖动、结束拖动、滚动结束）。 | The 15 `UIViewController` events of any object, plus window moves, entering and leaving the screen, and scrolling (drag begins, drag ends, scrolling ended). |
| 任意自定义事件：CYLTabBarController 发出角标时机 `cyl.badge.didShow` / `didClear` / `didBecomeReady` / `animationDidStart` / `animationDidStop`，以及 `cyl.core.tabBarItemsReady`；动画组件发出 `cyl.animation.didStart` / `didPause` / `didResume` / `didStop`。 | Any custom event: CYLTabBarController posts the badge moments `cyl.badge.didShow` / `didClear` / `didBecomeReady` / `animationDidStart` / `animationDidStop` and `cyl.core.tabBarItemsReady`; the animation components post `cyl.animation.didStart` / `didPause` / `didResume` / `didStop`. |
| 任意控件什么时候销毁：对象自己的销毁块，或全局的销毁观察者（只拿到描述，拿不到对象）。 | When any control is destroyed: the object's own teardown block, or the global dealloc observer (a description, never the object). |

## Insert your own behavior / 插入自定义行为

```swift
// One object
tabItem.cylAddLifecycleCallback(forCustomEvent: CYLAnimationEvent.didPause) { owner, _, info in /* … */ }

// Every object: pause all animations while the user scrolls, resume afterwards
CYLLifecycleCenter.addCallback(for: .scrollWillBeginDragging) { _, _, _ in animations.pauseAll() }
CYLLifecycleCenter.addCallback(for: .scrollDidEndScrolling) { _, _, _ in animations.resumeAll() }

// Know when any control with blocks is destroyed
CYLLifecycleCenter.addDeallocObserver { description, _ in print("destroyed \(description)") }
```

| 中文 | English |
|:--|:--|
| 其他平台同名：Android `LifecycleCenter.addCallback(event) { … }`、Flutter `LifecycleCenter.addCallback<Object>(LifecycleEvent…, (o, i, x) { … })`、React Native / HarmonyOS / 小程序 `LifecycleCenter.addCallback('scrollWillBeginDragging', (o, id, info) => …)`。每个平台的来源见 [Cross-Platform-API.md](Cross-Platform-API.md)。 | The other platforms use the same names: Android `LifecycleCenter.addCallback(event) { … }`, Flutter `LifecycleCenter.addCallback<Object>(LifecycleEvent…, (o, i, x) { … })`, React Native / HarmonyOS / Mini Program `LifecycleCenter.addCallback('scrollWillBeginDragging', (o, id, info) => …)`. The sources of each platform are in [Cross-Platform-API.md](Cross-Platform-API.md). |

## Pause while the user scrolls, in one call / 滚动时暂停，一行搞定

| 中文 | English |
|:--|:--|
| `whileUserScrolls` 是上面两条全局观察者的现成封装：任意被观察的滚动源开始拖动时执行 `pause`，彻底停止后执行 `resume`；返回的函数同时取消两者。同一个 key 再调用一次会替换原来的一对。转发不会让全局观察者对同一时机触发两次。 | `whileUserScrolls` is the ready-made form of the two global observers above: `pause` runs when any observed scroll source starts to be dragged, `resume` when it stopped for good; the returned function cancels both. Calling it again with the same key replaces the earlier pair. A forward does not make a global observer fire twice for one moment. |

```swift
let stop = CYLLifecycleCenter.whileUserScrolls(pause: { animations.pauseAll() }, resume: { animations.resumeAll() })
// later: stop()
```

## Debug log / 调试日志

| 中文 | English |
|:--|:--|
| 默认关闭，开启后每次触发都会记录：谁（类名与地址 / 名称）、什么事件、什么时机、执行了几个 block；自定义事件的发出；销毁。消息是惰性生成的，关闭时只有一次布尔判断的开销。`sink` 可以换成自己的日志。 | Off by default. On, every firing is logged: who (class and address / name), which event, which timing, how many blocks ran; every custom event posted; every teardown. Messages are built lazily, so off costs one boolean check. Replace `sink` to send them to your own logger. |

```swift
CYLLifecycleLog.isEnabled = true
CYLLifecycleLog.sink = { message in os_log("%{public}@", message) }
// [CYLLifecycle] UIButton@6000012 posts cyl.animation.didPause: 2 block(s)
// [CYLLifecycle] teardown CYLTabBarController@7f8: 1 block(s)
// [CYLLifecycle] dealloc CYLTabBarController@7f8
```

| 平台 | 开关 | Platform | Switch |
|:--|:--|:--|:--|
| iOS | `CYLLifecycleLog.isEnabled`, `.sink` | Android | `LifecycleLog.enabled`, `.sink`, `.describer` |
| Flutter | `LifecycleLog.enabled`, `.sink`, `.describer` | React Native, HarmonyOS, Mini Program | `LifecycleLog.enabled`, `.sink` |

## iOS: the owner of a global scroll moment / iOS：全局滚动时机的 owner

- [EN] On iOS a `CYLLifecycleCenter` observer of `scrollWillBeginDragging`, `scrollDidEndDragging` or `scrollDidEndScrolling` hears each moment once, and its `owner` is the **`UIScrollView`** that scrolled (not a cell, a view or a view controller that subscribed to it). `ownerType:` therefore filters on the scroll view's class. The blocks you add on a view or a view controller with `cylAddLifecycleCallback(for:)` still run first, with that object as the owner. On the other platforms the owner of a global scroll moment is the controller's owner (the page, the widget).
- [CN] iOS 上，`CYLLifecycleCenter` 的 `scrollWillBeginDragging`、`scrollDidEndDragging`、`scrollDidEndScrolling` 观察者对每个时机只收到一次，其 `owner` 是发生滚动的 **`UIScrollView`**（不是订阅它的 cell、视图或视图控制器），因此 `ownerType:` 按滚动视图的类过滤。在视图或视图控制器上用 `cylAddLifecycleCallback(for:)` 添加的 block 仍然先执行，owner 是该对象本身。其他平台上，全局滚动时机的 owner 是控制器的所有者（页面、组件）。
