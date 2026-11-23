# WeChat Mini Program usage / WeChat Mini Program 使用详解

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

Reference / 参考: [Cross-Platform-API.md](Cross-Platform-API.md) (every row and its test / 每一行及其测试), [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md) (iOS design / iOS 设计).

## Install / 安装

| 中文 | English |
|:--|:--|
| 源码在仓库的 `MiniProgram/`（CommonJS，无依赖）：把这个目录复制到小程序里，用 `require` 引入。 | The source is the repository's `MiniProgram/` (CommonJS, no dependencies): copy the folder into the Mini Program and `require` it. |

## Basic use / 基本用法

| 中文 | English |
|:--|:--|
| `withLifecycle(options)` 包装 `Page` 的选项：`onLoad`、`onShow`、`onReady`、`onHide`、`onUnload`、`onResize` 自动转交给控制器，页面里不用额外代码。`onUnload` 运行销毁块。Component 的 `lifetimes` 不会被包装，需要手动转交给 `LifecycleController`。 | `withLifecycle(options)` wraps the `Page` options: `onLoad`, `onShow`, `onReady`, `onHide`, `onUnload` and `onResize` reach the controller by themselves. `onUnload` runs the teardown blocks. A Component's `lifetimes` are not wrapped: forward them to a `LifecycleController` by hand. |
| 限制：没有 `super`；没有布局事件和安全区变化事件，对应的四个事件为 N/A；`onLoad` 的事件先于原来的 `onLoad` 触发，所以在 `onLoad` 里添加的块只会收到之后的事件。`WeakRef` 不可用时回退为强引用。 | Limits: no `super`; no layout or safe-area-change events, so four events are N/A; the load events fire before the original `onLoad`, so a block added inside `onLoad` only sees later events. Without `WeakRef` the owner is held strongly. |

```javascript
const { withLifecycle } = require('./MiniProgram');

Page(withLifecycle({
  onLoad() {
    this.cylController.registry.addLifecycleCallback('viewDidAppear', (page, id, info) => { /* ... */ });
    this.cylController.registry.addDeallocCallback((page) => wx.offThemeChange(page.themeListener), { key: 'theme' });
  },
}));
```
