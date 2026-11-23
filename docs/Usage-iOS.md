# iOS usage / iOS 使用详解

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

Reference / 参考: [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md) (design / 设计), [Cross-Platform-API.md](Cross-Platform-API.md) (other platforms / 其他平台).

## Install / 安装

| 中文 | English |
|:--|:--|
| CocoaPods：`pod 'CYLDeallocBlockExecutor'`。Swift Package Manager：`Package.swift` 里添加本仓库。Carthage：见 `Cartfile`。本库是纯 Swift，无需导入头文件。 | CocoaPods: `pod 'CYLDeallocBlockExecutor'`. Swift Package Manager: add this repository to `Package.swift`. Carthage: see `Cartfile`. The library is pure Swift: no header import. |

```ruby
pod 'CYLDeallocBlockExecutor'
```

## One line instead of dealloc / 一行代码代替 dealloc

| 中文 | English |
|:--|:--|
| 用 `cylWillDealloc` 的 block 代替 `dealloc`，block 在对象销毁时自动执行。 | A `cylWillDealloc` block replaces `dealloc`; it runs when the object is destroyed. |
| 不要在 block 里使用 `weak` 的 `self`：`weak` 变量在 dealloc 中已被置为 `nil`。`owner` 是 `Unmanaged<AnyObject>`（对应 Objective-C 的 `__unsafe_unretained id`），只在 block 内临时用 `owner.takeUnretainedValue()`，不要持有它，也不要让它逃出 block。 | Do not use a `weak` `self` in the block: weak variables are already `nil` during dealloc. `owner` is an `Unmanaged<AnyObject>` (Objective-C's `__unsafe_unretained id`); use `owner.takeUnretainedValue()` only inside the block, and never keep it or let it escape. |

```swift
foo.cylWillDealloc { owner, identifier in
    NotificationCenter.default.removeObserver(owner.takeUnretainedValue())
}
```

## Cancel / 取消回调

| 中文 | English |
|:--|:--|
| `cylWillDealloc` 返回任务标识（`UInt`），取消时传入它。真的取消了才返回 `true`。标识从 `1` 开始递增，dealloc 时 block 按标识从小到大执行；`0`（`cylDeallocCallbackIllegalIdentifier`）永远不是有效标识。对象开始销毁后已不能再取消。 | `cylWillDealloc` returns the identifier (`UInt`); pass it to cancel. It returns `true` only when a block was cancelled. Identifiers start at `1` and increase; at dealloc the blocks run in ascending identifier order; `0` (`cylDeallocCallbackIllegalIdentifier`) is never valid. Once destruction has started a block can no longer be cancelled. |
| 带 key 的 block（`cylWillDealloc(key:callback:)`、`cylCancelDeallocCallback(key:)`）是 1.4.0 新增、尚未发布的功能，不需要保存标识。 | Keyed blocks (`cylWillDealloc(key:callback:)`, `cylCancelDeallocCallback(key:)`) are new in 1.4.0 and not released yet; no identifier needs saving. |

```swift
let id = foo.cylWillDealloc { owner, identifier in /* ... */ }
foo.cylCancelDeallocCallback(identifier: id)   // true when cancelled
foo.cylCancelAllDeallocCallbacks()
```

## Observer outlives the observed controller (issue #8) / 观察者比被观察的控制器活得久（issue #8）

| 中文 | English |
|:--|:--|
| iOS 11 之后，`UIViewController` 可能比观察它的 `view` 先销毁（释放顺序问题，不是循环引用）。观察者在被观察的控制器上注册一个 dealloc block，控制器先销毁时由它完成清理；观察者先销毁时在 `deinit` 里移除观察。 | Since iOS 11 a `UIViewController` can be destroyed before the `view` that observes it (a release-order problem, not a retain cycle). The observer registers a dealloc block on the controller to clean up when the controller goes first, and removes the observation in `deinit` when the observer goes first. |

```swift
final class ObserverView: UIView {
    unowned(unsafe) var viewController: UIViewController?

    func observe(_ viewController: UIViewController) {
        self.viewController = viewController
        viewController.addObserver(self, forKeyPath: "view", options: .new, context: nil)
        viewController.cylWillDealloc { [weak self] owner, _ in
            guard let self else { return }
            (owner.takeUnretainedValue() as! NSObject).removeObserver(self, forKeyPath: "view")
            self.viewController = nil
        }
    }

    deinit { viewController?.removeObserver(self, forKeyPath: "view") }
}
```

## Lifecycle blocks / 生命周期 block

| 中文 | English |
|:--|:--|
| 除 dealloc 外，`UIViewController` 的生命周期也能加 block：一行代码，可加多个，按添加顺序执行，按标识或 key 取消。`owner` 的类型就是当前类，不必捕获 `self`。 | Besides dealloc, `UIViewController` lifecycle events take blocks too: one line, several blocks per event, run in the order added, cancelled by identifier or key. `owner` has the class's own type, so `self` need not be captured. |
| `timing`：`.beforeSuper`（顶部，`super` 之前）、`.afterSuper`（默认，顶部，`super` 之后）、`.end`（底部；重写了该方法的类要在重写里调用 `cylPerformLifecycle`）。 | `timing`: `.beforeSuper` (top, before `super`), `.afterSuper` (default, top, after `super`), `.end` (bottom; a class that overrides the method calls `cylPerformLifecycle` in the override). |
| 事件：`viewDidLoad`、`viewWillAppear`、`viewIsAppearing`、`viewDidAppear`、`viewWillLayoutSubviews`、`viewDidLayoutSubviews`、`viewWillDisappear`、`viewDidDisappear`、`viewSafeAreaInsetsDidChange`、`viewLayoutMarginsDidChange`、`traitCollectionDidChange`、`viewWillTransition`、`willMoveToParent`、`didMoveToParent`、`didReceiveMemoryWarning`。 | Events: the same fifteen names. |

```swift
cylAddLifecycleCallback(for: .viewWillAppear) { owner, identifier, info in
    // owner has the type of the current class
}

// Run once; re-arm with cylRearmLifecycleCallbacks(for:)
cylAddLifecycleCallback(for: .viewDidLayoutSubviews, timing: .end, invokeOnce: true) { owner, _, _ in
    owner.setUpBadges()
}

// Re-apply the skin on dark mode changes
cylAddLifecycleCallback(for: .traitCollectionDidChange) { owner, _, info in
    guard owner.traitCollection.hasDifferentColorAppearance(comparedTo: info.previousTraitCollection) else { return }
    owner.applyTheme()
}

// Replace by key: the last block added under a key is the only one kept.
// A keyed block belongs to whoever holds the key: cancel-all and re-arm by event skip it.
cylWillDealloc(key: "theme.removeObserver") { owner, _, _ in
    NotificationCenter.default.removeObserver(owner.takeUnretainedValue())
}
```

| 中文 | English |
|:--|:--|
| dealloc 也有同样参数的版本 `cylWillDealloc(callback:)`（owner、identifier、info），与生命周期 block 共用标识序列、锁和取消方式；1.3.0 的 `cylWillDealloc(selfCallback:)` 不变。 | dealloc has the same shape, `cylWillDealloc(callback:)` (owner, identifier, info), sharing the identifier sequence, the lock and the cancel calls with lifecycle blocks; the 1.3.0 `cylWillDealloc(selfCallback:)` is unchanged. |

## Migrating from Objective-C / 从 Objective-C 版本迁移

| Objective-C | Swift |
|:--|:--|
| `cyl_willDeallocWithSelfCallback:` | `cylWillDealloc(selfCallback:)` |
| `cyl_cancelDeallocCallbackWithIdentifier:` | `cylCancelDeallocCallback(identifier:)` |
| `cyl_cancelAllDeallocCallbacks` | `cylCancelAllDeallocCallbacks()` |
| `cyl_executeAtDealloc:` (deprecated) | `cyl_executeAtDealloc(_:)` (deprecated) |
| `CYLDeallocCallbackIllegalIdentifier` | `cylDeallocCallbackIllegalIdentifier` |

| 中文 | English |
|:--|:--|
| 1.4.0 的行为变化：`cylCancelDeallocCallback(identifier:)` 只在真的取消了 block 时返回 `true`。 | Change in 1.4.0: `cylCancelDeallocCallback(identifier:)` returns `true` only when a block was really cancelled. |

## Scenarios / 应用场景

| 中文 | English |
|:--|:--|
| 管理 KVO 与 `NSNotificationCenter` 的 `removeObserver`：`addObserver` 与 `removeObserver` 写在同一处（比如 setter），即使在分类里也不需要 `dealloc`。换肤场景见 [Scenario-Theme-CYLTabBarController.md](Scenario-Theme-CYLTabBarController.md)。 | Managing `removeObserver` for KVO and `NSNotificationCenter`: `addObserver` and `removeObserver` live together (a setter, even in a category), with no `dealloc`. The skin-switching scenario is in [Scenario-Theme-CYLTabBarController.md](Scenario-Theme-CYLTabBarController.md). |
| 模拟 `weak` 属性：`OBJC_ASSOCIATION_ASSIGN` 保存对象，再在对象上注册 dealloc block 清掉关联引用。 | Simulating a `weak` property: store the object with `OBJC_ASSOCIATION_ASSIGN`, and register a dealloc block on it that clears the association. |
| 取代 flag：CYLTabBarController 用 flag 保证 `viewDidLoad` 没被调用时 `deinit` 不会 `removeObserver`；在添加监听的地方同时添加 dealloc block 就不再需要 flag。 | Replacing flags: CYLTabBarController used a flag so `deinit` would not `removeObserver` when `viewDidLoad` never ran; adding the dealloc block where the observer is added removes the need for the flag. |

```swift
private var objectKey: UInt8 = 0

final class Holder: NSObject {
    var object: NSObject? {
        get { objc_getAssociatedObject(self, &objectKey) as? NSObject }
        set {
            objc_setAssociatedObject(self, &objectKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
            newValue?.cylWillDealloc { [weak self] _, _ in
                guard let self else { return }
                objc_setAssociatedObject(self, &objectKey, nil, .OBJC_ASSOCIATION_ASSIGN)
            }
        }
    }
}

// Where the observer is added (no flag): capture the observed object, never read it through owner.
override func viewDidLoad() {
    super.viewDidLoad()
    let observedTabBar = tabBar
    observedTabBar.addObserver(self, forKeyPath: "swappableImageViewDefaultOffset", options: .new, context: nil)
    cylWillDealloc(key: "kvo.swappableImageViewDefaultOffset") { owner, _, _ in
        observedTabBar.removeObserver(owner.takeUnretainedValue() as! NSObject, forKeyPath: "swappableImageViewDefaultOffset")
    }
}
```

## `__unsafe_unretained` and Swift / `__unsafe_unretained` 与 Swift

| 中文 | English |
|:--|:--|
| Objective-C 的 `__unsafe_unretained` 对应 Swift 的 `unowned(unsafe)`：不改变引用计数，对象释放后也不会置 `nil`，继续访问是未定义行为。销毁阶段 `weak` 已是 `nil`，所以本库用 `Unmanaged<AnyObject>` 拿到“正在销毁”的对象。 | Objective-C's `__unsafe_unretained` is Swift's `unowned(unsafe)`: no retain count change, no `nil` after release, undefined behavior on use. During destruction `weak` is already `nil`, so the library hands the dying object over as `Unmanaged<AnyObject>`. |

### The owner of a global scroll observer / 全局滚动观察者的 owner

- [EN] A `CYLLifecycleCenter` scroll observer gets the `UIScrollView` as `owner`, once per moment, whatever number of views subscribed to it. Details: [Observing-and-Debugging](Observing-and-Debugging.md).
- [CN] `CYLLifecycleCenter` 的滚动观察者收到的 `owner` 是 `UIScrollView`，每个时机一次，与订阅它的视图数量无关。详见 [Observing-and-Debugging](Observing-and-Debugging.md)。
