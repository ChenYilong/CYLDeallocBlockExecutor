# Flutter usage / Flutter 使用详解

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

Reference / 参考: [Cross-Platform-API.md](Cross-Platform-API.md) (every row and its test / 每一行及其测试), [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md) (iOS design / iOS 设计).

## Install / 安装

| 中文 | English |
|:--|:--|
| 包 `cyl_dealloc_block_executor` 在仓库的 `Flutter/` 目录（还未发布到 pub.dev），用 path 或 git 依赖。 | The package `cyl_dealloc_block_executor` is the repository's `Flutter/` folder (not on pub.dev yet): use a path or git dependency. |

```yaml
dependencies:
  cyl_dealloc_block_executor:
    git:
      url: https://github.com/ChenYilong/CYLDeallocBlockExecutor.git
      path: Flutter
      ref: feat/lifecycle-callbacks
```

## Basic use / 基本用法

| 中文 | English |
|:--|:--|
| 给 `State` 加上 `CYLLifecycleMixin`，事件就自动触发：`initState` / `activate` / `deactivate`、`RouteAware`（出现与消失，需提供 `lifecycleRouteObserver`）、`WidgetsBindingObserver`（尺寸、安全区、亮暗、文字缩放、内存压力）。`dispose` 时运行销毁块，是确定的。 | Add `CYLLifecycleMixin` to a `State` and the events fire by themselves: `initState` / `activate` / `deactivate`, `RouteAware` (appear and disappear; provide `lifecycleRouteObserver`), `WidgetsBindingObserver` (size, safe area, brightness, text scale, memory pressure). Teardown blocks run in `dispose`, deterministically. |
| 限制：Dart 无法判断子类是否重写方法，所以 `end` 时机只能手动派发；页面内的 Tab 切换（`IndexedStack`）不会触发出现事件；`viewLayoutMarginsDidChange` 为 N/A。 | Limits: Dart cannot tell whether a subclass overrides a method, so the `end` timing is manual only; a tab switch inside one route (`IndexedStack`) fires no appear event; `viewLayoutMarginsDidChange` is N/A. |

```dart
class _PageState extends State<Page> with CYLLifecycleMixin<Page> {
  @override
  RouteObserver<ModalRoute<dynamic>>? get lifecycleRouteObserver => routeObserver;

  @override
  void initState() {
    super.initState();
    lifecycle.addLifecycleCallback<_PageState>(
      LifecycleEvent.viewWillAppear,
      (owner, id, info) { /* ... */ },
    );
    lifecycle.addLifecycleCallback<_PageState>(
      LifecycleEvent.traitCollectionDidChange,
      (owner, id, info) => owner.applyTheme(),
      key: 'theme',
    );
    lifecycle.addDeallocCallback<_PageState>((owner, id, info) => themeCenter.remove(owner), key: 'theme');
  }

  @override
  Widget build(BuildContext context) => layoutLifecycle(child: const Placeholder());
}
```
