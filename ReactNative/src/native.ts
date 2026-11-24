// The only file that imports `react-native` and `react`. Not covered by the
// Node tests (they do not load); the controller it feeds is.
import { useCallback, useEffect, useRef } from 'react';
import { Appearance, AppState, DeviceEventEmitter, Dimensions, Platform } from 'react-native';
import { LifecycleController, mountLifecycle } from './controller.ts';
import type { ControllerOptions, PlatformSources } from './controller.ts';
import { LifecycleRegistry } from './registry.ts';
import type { Insets } from './types.ts';

/** The real platform sources. Pass `navigation` and `safeAreaInsets` when the screen has them. */
export function createNativeSources(extra: {
  navigation?: PlatformSources['navigation'];
  safeAreaInsets?: { get(): Insets; subscribe(listener: (insets: Insets) => void): { remove(): void } | (() => void) };
} = {}): PlatformSources {
  return {
    platform: Platform.OS,
    appState: AppState as unknown as PlatformSources['appState'],
    dimensions: Dimensions as unknown as PlatformSources['dimensions'],
    appearance: Appearance as unknown as PlatformSources['appearance'],
    hostEvents: DeviceEventEmitter as unknown as PlatformSources['hostEvents'],
    navigation: extra.navigation,
    safeAreaInsets: extra.safeAreaInsets,
  };
}

/**
 * Lifecycle blocks for the calling component: mounted in an effect, unmounted
 * in its cleanup. Every mount makes a new controller on the owner's registry, so
 * React StrictMode's mount, unmount, mount works (the simulated unmount runs
 * the teardown blocks). Add blocks through `registry`; spread `onLayout` onto
 * the view. Use `navigation: 'immediate'` under tab navigators without animation.
 */
export function useLifecycle<T extends object>(
  owner: T,
  extra?: Parameters<typeof createNativeSources>[0] & { navigationMode?: ControllerOptions['navigation'] },
) {
  const current = useRef<LifecycleController<T> | null>(null);
  const registry = LifecycleRegistry.of(owner);
  useEffect(() => {
    const mounted = mountLifecycle(owner, createNativeSources(extra), { navigation: extra?.navigationMode });
    current.current = mounted.controller;
    return () => {
      current.current = null;
      mounted.unmount();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [owner, extra?.navigation, extra?.safeAreaInsets, extra?.navigationMode]);
  const onLayout = useCallback((event?: unknown) => current.current?.onLayout(event), []);
  // [EN] Spread onto a ScrollView / FlatList: the controller fires the scroll moments (scrollWillBeginDragging …
  //      scrollDidEndScrolling) that `LifecycleCenter.whileUserScrolls` listens to. [CN] 展开到 ScrollView / FlatList 上。
  const scrollHandlers = useRef({
    onScrollBeginDrag: (e?: unknown) => current.current?.scrollHandlers.onScrollBeginDrag(e),
    onScrollEndDrag: (e?: unknown) => current.current?.scrollHandlers.onScrollEndDrag(e),
    onMomentumScrollBegin: (e?: unknown) => current.current?.scrollHandlers.onMomentumScrollBegin(e),
    onMomentumScrollEnd: (e?: unknown) => current.current?.scrollHandlers.onMomentumScrollEnd(e),
  }).current;
  // [EN] Tell the controller the screen is visible or not (didEnterScreen / didLeaveScreen). [CN] 通知屏幕可见性。
  const setScreenVisible = useCallback((visible: boolean) => current.current?.setScreenVisible(visible), []);
  return { registry, onLayout, scrollHandlers, setScreenVisible };
}
