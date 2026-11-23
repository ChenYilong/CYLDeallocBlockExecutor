import { LifecycleRegistry } from './registry';
import type { LifecycleEvent, LifecycleInfo } from './types';

/** `wx.onWindowResize` size. */
export interface MiniProgramSize { windowWidth?: number; windowHeight?: number; size?: { windowWidth: number; windowHeight: number } }

/**
 * The lifecycle controller of one page or component (the owner `T`, received typed by every block).
 * Call the `on*` methods from the matching page handlers, or use `withLifecycle`.
 */
export declare class LifecycleController<T extends object = object> {
  constructor(owner: T);
  readonly owner: T;
  readonly registry: LifecycleRegistry;
  /** True once `onUnload()` ran. */
  readonly isDetached: boolean;
  /** Milliseconds without a scroll event that end scrolling. */
  scrollEndDelay: number;
  around(event: LifecycleEvent, info?: LifecycleInfo | Record<string, unknown>): void;
  onLoad(): void;
  onShow(): void;
  onReady(): void;
  onHide(): void;
  onUnload(): void;
  screenVisible(visible: boolean): void;
  observeScreen(selector: string, options?: Record<string, unknown>, api?: unknown): () => void;
  onPageScroll(event?: { scrollTop?: number }): void;
  endScrolling(event?: unknown): void;
  onResize(size?: MiniProgramSize): void;
  themeChanged(theme: string): void;
  memoryWarning(): void;
}

/** Wraps `Page({...})` / `Component({...})` options so the controller sees every handler; adds `cyl` (the controller) after `onLoad`. */
export declare function withLifecycle<O extends object>(options: O): O & { cyl?: LifecycleController };
