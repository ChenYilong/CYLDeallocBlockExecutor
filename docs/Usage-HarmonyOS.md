# HarmonyOS usage / HarmonyOS 使用详解

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

Reference / 参考: [Cross-Platform-API.md](Cross-Platform-API.md) (every row and its test / 每一行及其测试), [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md) (iOS design / iOS 设计).

## Install / 安装

| 中文 | English |
|:--|:--|
| 源码在仓库的 `HarmonyOS/`（普通 TypeScript），HAR 模块脚手架在 `HarmonyOS/cyldeallocblockexecutor`。脚手架是静态编写的，尚未用 hvigor 构建；ArkTS 严格规则可能不接受 `any`、`in`、对象展开，见 [Cross-Platform-API.md](Cross-Platform-API.md)。 | The source is the repository's `HarmonyOS/` (plain TypeScript); the HAR module scaffolding is `HarmonyOS/cyldeallocblockexecutor`. The scaffolding was written statically and never built with hvigor; ArkTS's strict rules may reject `any`, `in` and object spread, see [Cross-Platform-API.md](Cross-Platform-API.md). |

## Basic use / 基本用法

| 中文 | English |
|:--|:--|
| 页面把自己的回调转交给 `LifecycleController`：`aboutToAppear`、`onPageShow`、`onPageHide`、`aboutToDisappear`、`onAreaChange`、窗口避让区、配置变化、`onMemoryLevel`。`aboutToDisappear` 运行销毁块。 | The page forwards its own callbacks to `LifecycleController`: `aboutToAppear`, `onPageShow`, `onPageHide`, `aboutToDisappear`, `onAreaChange`, window avoid areas, configuration changes, `onMemoryLevel`. `aboutToDisappear` runs the teardown blocks. |
| 限制：ArkUI 没有 `super`，也没有过渡结束回调，所以出现的三个事件连续触发；`viewWillLayoutSubviews`、`viewLayoutMarginsDidChange` 为 N/A。 | Limits: ArkUI has no `super` and no transition end, so the three appear events fire back to back; `viewWillLayoutSubviews` and `viewLayoutMarginsDidChange` are N/A. |

```typescript
@Entry
@Component
struct Page {
  private lifecycle: LifecycleController<Page> = new LifecycleController<Page>(this);

  aboutToAppear(): void {
    this.lifecycle.registry.addLifecycleCallback('viewDidLoad', (owner, id, info) => { /* ... */ });
    this.lifecycle.registry.addDeallocCallback((owner, id, info) => themeCenter.remove(owner), { key: 'theme' });
    this.lifecycle.aboutToAppear();
  }
  onPageShow(): void { this.lifecycle.onPageShow(); }
  onPageHide(): void { this.lifecycle.onPageHide(); }
  aboutToDisappear(): void { this.lifecycle.aboutToDisappear(); }
  build() { Column() {}.onAreaChange((o, n) => this.lifecycle.onAreaChange(o, n)) }
}
```
