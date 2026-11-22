// The only file that imports `react-native` and `react`. Not covered by the
// Node tests (they do not load); the controller it feeds is.
import { useEffect, useRef } from 'react';
import { Appearance, AppState, Dimensions, Platform } from 'react-native';
import { LifecycleController } from './controller.ts';
import type { PlatformSources } from './controller.ts';
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
    navigation: extra.navigation,
    safeAreaInsets: extra.safeAreaInsets,
  };
}

/**
 * A controller for the calling component: attached on mount, detached on
 * unmount. Add blocks through `controller.registry` (before the first render
 * commits, for the load events). Spread `controller.onLayout` onto the view.
 */
export function useLifecycle<T extends object>(owner: T, extra?: Parameters<typeof createNativeSources>[0]) {
  const ref = useRef<LifecycleController<T> | null>(null);
  if (ref.current === null) ref.current = new LifecycleController(owner, createNativeSources(extra));
  const controller = ref.current;
  useEffect(() => {
    controller.attach();
    return () => controller.detach();
  }, [controller]);
  return controller;
}
