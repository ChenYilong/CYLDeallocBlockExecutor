# Scenario: skin switching in CYLTabBarController / 场景：CYLTabBarController 换肤

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

| 中文 | English |
|:--|:--|
| 这是 README 里“换肤”示例在 [CYLTabBarController](https://github.com/ChenYilong/CYLTabBarController) 上的应用。**假设 CYLTabBarController 已经依赖本库**（iOS 用 CocoaPods / SPM 的 `CYLDeallocBlockExecutor`，其他平台用各自的包）。下面的片段是改造后的写法，是示意代码，没有在 CYLTabBarController 里编译运行；真实的接入点见该仓库的 `docs/Lifecycle-Library.md`。 | This applies the README's skin-switching example to [CYLTabBarController](https://github.com/ChenYilong/CYLTabBarController). **It assumes CYLTabBarController already depends on this library** (the `CYLDeallocBlockExecutor` pod / SPM package on iOS, each platform's own package elsewhere). The snippets are the refactored shape, illustrative, and were not compiled in CYLTabBarController; the real integration points are in that repository's `docs/Lifecycle-Library.md`. |

## The three jobs / 三件事

| 中文 | English |
|:--|:--|
| 1. **换肤监听配对**：添加通知（或监听）的地方，同时用 key 注册移除它的销毁块；同一个 key 只保留最后一个，所以 setter 调多次也只有一份。 | 1. **Pair the observer**: where the notification (or listener) is added, register the block that removes it under a key; one key keeps only the last block, so a setter called twice still leaves one. |
| 2. **深色模式 / 系统外观变化时重新换肤**：用 `traitCollectionDidChange`（`.afterSuper`）的块，不再写重写方法。 | 2. **Re-apply the skin on a system appearance change**: a `traitCollectionDidChange` block (`.afterSuper`) replaces an override. |
| 3. **每次换肤后让“只执行一次”的布局 block 重新执行一次**：布局 block 用 `.end` + `invokeOnce` + key `cyl.core.layoutBlock` 注册，换肤后按 key 重新启用（只动核心自己的块，不会重跑 App 的一次性块）。 | 3. **After each skin change let the one-time layout block run once more**: the layout block is registered with `.end` + `invokeOnce` + the key `cyl.core.layoutBlock`, and re-armed by key after the skin change (only the core's block, never the app's own run-once blocks). |

## iOS (Swift)

```swift
// CYLTabBarController (core)
func installThemeObservers() {
    // 1. paired observer, replaced by key
    NotificationCenter.default.removeObserver(self, name: .cylThemeDidChange, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(themeChanged(_:)), name: .cylThemeDidChange, object: nil)
    cylWillDealloc(key: "cyl.core.themeObserver") { owner, _, _ in
        NotificationCenter.default.removeObserver(owner.takeUnretainedValue())
    }

    // 2. dark mode and size class changes
    cylAddLifecycleCallback(for: .traitCollectionDidChange, key: "cyl.core.themeTrait") { owner, _, info in
        guard owner.traitCollection.hasDifferentColorAppearance(comparedTo: info.previousTraitCollection) else { return }
        owner.applyTabBarTheme()
    }
}

func applyTabBarTheme() {
    // ... apply the skin to the tabs and the plus button ...
    // 3. the app's one-time layout block runs once more
    _ = cylRearmLifecycleCallback(key: "cyl.core.layoutBlock")
}
```

## Android (Kotlin)

```kotlin
// CYLTabBarController (core): a custom class, not an Activity, so it dispatches itself
private val callbacks = LifecycleRegistry.of(this)

fun installThemeObservers() {
    val listener = ThemeListener { applyTabBarTheme() }
    ThemeCenter.add(listener)
    callbacks.addDeallocCallback<CYLTabBarController>(key = "cyl.core.themeListener") { _, _, _ -> ThemeCenter.remove(listener) }
}

fun applyTabBarTheme() {
    // ... apply the skin ...
    callbacks.rearmLifecycleCallback("cyl.core.layoutBlock")
}
// The host Activity's configuration change reaches traitCollectionDidChange through AndroidBinding.
```

## Flutter (Dart)

```dart
class _CYLTabBarState extends State<CYLTabBar> with CYLLifecycleMixin<CYLTabBar> {
  @override
  void initState() {
    super.initState();
    final listener = themeCenter.add(applyTheme);
    lifecycle.addDeallocCallback<_CYLTabBarState>((o, id, info) => themeCenter.remove(listener), key: 'cyl.core.themeListener');
    lifecycle.addLifecycleCallback<_CYLTabBarState>(
      LifecycleEvent.traitCollectionDidChange,
      (o, id, info) => o.applyTheme(),
      key: 'cyl.core.themeTrait',
    );
  }

  void applyTheme() {
    // ... apply the skin ...
    lifecycle.rearmLifecycleCallback(key: 'cyl.core.layoutBlock');
  }
}
```

## React Native (TypeScript)

```tsx
function CYLTabBar(props) {
  const owner = useRef({}).current;
  const { registry, onLayout } = useLifecycle(owner);

  useEffect(() => {
    const listener = themeCenter.add(applyTheme);
    registry.addDeallocCallback(() => themeCenter.remove(listener), { key: 'cyl.core.themeListener' });
    registry.addLifecycleCallback('traitCollectionDidChange', () => applyTheme(), { key: 'cyl.core.themeTrait' });
  }, [registry]);

  function applyTheme() {
    // ... apply the skin ...
    registry.rearmLifecycleCallback('cyl.core.layoutBlock');
  }
  return <View onLayout={onLayout} />;
}
```

## HarmonyOS (ArkTS)

```typescript
@Component
struct CYLTabBarController {
  private lifecycle: LifecycleController<CYLTabBarController> = new LifecycleController<CYLTabBarController>(this);

  aboutToAppear(): void {
    const listener = themeCenter.add(() => this.applyTheme());
    this.lifecycle.registry.addDeallocCallback<CYLTabBarController>(() => themeCenter.remove(listener), { key: 'cyl.core.themeListener' });
    this.lifecycle.registry.addLifecycleCallback<CYLTabBarController>('traitCollectionDidChange', () => this.applyTheme(), { key: 'cyl.core.themeTrait' });
    this.lifecycle.aboutToAppear();
  }
  aboutToDisappear(): void { this.lifecycle.aboutToDisappear(); }
  // the page forwards colorModeChanged(mode) from onConfigurationUpdate to the controller

  applyTheme(): void {
    // ... apply the skin ...
    this.lifecycle.registry.rearmLifecycleCallback('cyl.core.layoutBlock');
  }
}
```

## WeChat Mini Program (JavaScript)

```javascript
Component({
  lifetimes: {
    attached() {
      this.cylLifecycle = new LifecycleController(this);
      this.cylLifecycle.onLoad();
      const listener = (result) => this.applyTheme(result.theme);
      wx.onThemeChange(listener);
      this.cylLifecycle.registry.addDeallocCallback(() => wx.offThemeChange(listener), { key: 'cyl.core.themeListener' });
    },
    detached() { this.cylLifecycle.onUnload(); },   // runs the teardown blocks
  },
  methods: {
    applyTheme(theme) {
      this.cylLifecycle.themeChanged(theme);          // fires traitCollectionDidChange blocks
      // ... apply the skin ...
      this.cylLifecycle.registry.rearmLifecycleCallback('cyl.core.layoutBlock');
    },
  },
});
```

## Rules to keep / 要遵守的规则

| 中文 | English |
|:--|:--|
| 核心使用以 `cyl.core.` 开头的 key，App 用自己的 key 或不用 key；库不特殊对待前缀。带 key 的块只能按 key 取消或重新启用，按事件的全部取消 / 重新启用不会碰到它们。 | The core uses keys that start with `cyl.core.`; apps use their own keys or none; the library does not treat the prefix specially. A keyed block is cancelled or re-armed by key only: the by-event calls skip it. |
| 销毁块里捕获被监听的对象，不要通过 `owner` 读取：UIKit 的成员此时可能已经释放。 | In a teardown block capture the observed object; never read it through `owner`: UIKit's members may already be released. |
