# React Native usage / React Native 使用详解

中英文对照：每段先中文，后英文。代码只写一份。
Chinese first, English second, in every pair. Code is written once.

Reference / 参考: [Cross-Platform-API.md](Cross-Platform-API.md) (every row and its test / 每一行及其测试), [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md) (iOS design / iOS 设计).

## Install / 安装

| 中文 | English |
|:--|:--|
| 包在仓库的 `ReactNative/` 目录（TypeScript，未发布到 npm）。核心 `registry` 与 `controller` 不依赖 `react-native`，只有 `native.ts` 引入 `react-native` 和 `react`。 | The package is the repository's `ReactNative/` folder (TypeScript, not on npm yet). The core `registry` and `controller` do not import `react-native`; only `native.ts` imports `react-native` and `react`. |

```json
{ "dependencies": { "cyl-dealloc-block-executor": "github:ChenYilong/CYLDeallocBlockExecutor#feat/lifecycle-callbacks" } }
```

## Basic use / 基本用法

| 中文 | English |
|:--|:--|
| `useLifecycle(owner)` 在组件挂载时开始、卸载时清理（兼容 StrictMode 的“挂载-卸载-挂载”）。事件来源：挂载 / 卸载、React Navigation 的 `focus` / `blur` / `transition*`、`onLayout`、`Dimensions`、`Appearance`、`AppState`（`memoryWarning` 仅 iOS）、安全区（需要注入）。 | `useLifecycle(owner)` starts on mount and cleans up on unmount (it handles StrictMode's mount, unmount, mount). Sources: mount / unmount, React Navigation `focus` / `blur` / `transition*`, `onLayout`, `Dimensions`, `Appearance`, `AppState` (`memoryWarning`: iOS only), safe area (inject it). |
| 限制：React 没有 `super`，`beforeSuper` 与 `afterSuper` 连续触发；`viewWillLayoutSubviews`、`viewLayoutMarginsDidChange` 为 N/A；Tab 导航不带动画时用 `navigationMode: 'immediate'`。 | Limits: React has no `super`, so `beforeSuper` and `afterSuper` fire back to back; `viewWillLayoutSubviews` and `viewLayoutMarginsDidChange` are N/A; use `navigationMode: 'immediate'` under tab navigators without animation. |

```tsx
import { useLifecycle } from 'cyl-dealloc-block-executor/src/native';

function Screen({ navigation }) {
  const owner = useRef({}).current;
  const { registry, onLayout } = useLifecycle(owner, { navigation });

  useEffect(() => {
    registry.addLifecycleCallback('viewWillAppear', (o, id, info) => { /* ... */ });
    registry.addLifecycleCallback('traitCollectionDidChange', (o, id, info) => applyTheme(info.previousColorScheme), { key: 'theme' });
    registry.addDeallocCallback((o) => themeCenter.remove(o), { key: 'theme' });
  }, [registry]);

  return <View onLayout={onLayout} />;
}
```
