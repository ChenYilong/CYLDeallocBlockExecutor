import { LifecycleRegistry } from './registry.ts';
import type { Insets, LifecycleEvent, LifecycleInfo } from './types.ts';

type Remove = () => void;
type Sub = { remove(): void } | (() => void) | void;

/**
 * The platform sources the controller listens to. They are injected so the
 * controller never imports `react-native` (see `native.ts` for the real ones).
 * Every source is optional; a missing source leaves its events unfired.
 */
export interface PlatformSources {
  platform?: 'ios' | 'android' | string;
  /** `AppState`: only `memoryWarning` is used (iOS only). */
  appState?: { addEventListener(type: 'memoryWarning', listener: () => void): Sub };
  /** `Dimensions`: `change` with the new window size. */
  dimensions?: {
    addEventListener(
      type: 'change',
      listener: (e: { window: { width: number; height: number; fontScale?: number } }) => void,
    ): Sub;
    get(dim: 'window'): { width: number; height: number; fontScale?: number };
  };
  /** `Appearance`. */
  appearance?: {
    addChangeListener(listener: (p: { colorScheme: string | null | undefined }) => void): Sub;
    getColorScheme(): string | null | undefined;
  };
  /** A React Navigation `navigation` object (`transitionStart`, `transitionEnd`, `focus`, `beforeRemove`). */
  navigation?: { addListener(type: string, listener: (e?: any) => void): Sub };
  /** Safe area insets (for example `react-native-safe-area-context`). */
  safeAreaInsets?: { get(): Insets; subscribe(listener: (insets: Insets) => void): Sub };
}

function toRemove(sub: Sub): Remove {
  return () => {
    if (typeof sub === 'function') sub();
    else if (sub && typeof sub.remove === 'function') sub.remove();
  };
}

const sameInsets = (a: Insets, b: Insets) =>
  a.top === b.top && a.left === b.left && a.bottom === b.bottom && a.right === b.right;

/**
 * Fires the lifecycle events of an owner (a component, a screen or any
 * object) without code in its handlers: the React counterpart of the iOS
 * `UIViewController` hook.
 *
 * Mapping (iOS event: React Native source):
 * - `viewDidLoad`, `willMoveToParent` / `didMoveToParent`: `attach()` (mount)
 *   and `detach()` (unmount, `beforeRemove` of the navigation);
 * - `viewWillAppear` / `viewWillDisappear`: navigation `transitionStart`
 *   (`closing` false / true); `viewIsAppearing`: navigation `focus`;
 *   `viewDidAppear` / `viewDidDisappear`: navigation `transitionEnd`. App
 *   foreground and background never feed an appear event (as on iOS);
 * - `viewDidLayoutSubviews`: `onLayout(event)`; `viewWillLayoutSubviews` has
 *   no source (React Native reports layout after the fact);
 * - `viewSafeAreaInsetsDidChange`: `safeAreaInsets`; `viewWillTransition`:
 *   `Dimensions` `change`; `traitCollectionDidChange`: `Appearance` and the
 *   font scale; `didReceiveMemoryWarning`: `AppState` `memoryWarning` (iOS
 *   only, Android has no such event);
 * - `viewLayoutMarginsDidChange`: not available (no layout margins).
 *
 * Sources are subscribed lazily, when the first block for one of their events
 * is added, and removed in `detach()`. Teardown blocks run in `detach()`.
 */
export class LifecycleController<T extends object> {
  readonly registry: LifecycleRegistry;
  private readonly owner: T;
  private readonly sources: PlatformSources;
  private readonly removers = new Map<string, Remove>();
  private attached = false;
  private detached = false;
  private appearPending = false;
  private disappearPending = false;
  private lastColorScheme: string | null | undefined;
  private lastFontScale: number | undefined;
  private lastInsets: Insets | undefined;
  private lastSize: { width: number; height: number } | undefined;

  constructor(owner: T, sources: PlatformSources = {}) {
    this.owner = owner;
    this.sources = sources;
    this.registry = LifecycleRegistry.of(owner);
    this.registry.hookInstalled = true;
    this.registry.onRegister = (event) => this.subscribeFor(event);
  }

  private around(event: LifecycleEvent, info: Partial<LifecycleInfo> = {}, call?: () => void): void {
    this.registry.fireAutomatic(event, 'beforeSuper', info);
    call?.();
    this.registry.fireAutomatic(event, 'afterSuper', info);
  }

  /** The owner was added to its parent (mount). Fires the load and move events. */
  attach(): void {
    if (this.attached) return;
    this.attached = true;
    this.around('willMoveToParent', { parentAttached: true });
    this.around('viewDidLoad');
    this.around('didMoveToParent', { parentAttached: true });
    this.subscribeAll();
  }

  /** The owner was removed (unmount): move events, sources removed, teardown blocks run. */
  detach(): void {
    if (this.detached) return;
    this.detached = true;
    this.flushPending();
    this.around('willMoveToParent', { parentAttached: false });
    this.around('didMoveToParent', { parentAttached: false });
    for (const remove of this.removers.values()) remove();
    this.removers.clear();
    this.registry.runDealloc();
  }

  /** The `onLayout` handler of the owner's view. */
  onLayout = (_event?: unknown): void => {
    this.around('viewDidLayoutSubviews');
  };

  private flushPending(): void {
    this.didAppear();
    this.didDisappear();
  }

  private didAppear(): void {
    if (!this.appearPending) return;
    this.appearPending = false;
    this.around('viewDidAppear', { animated: true });
  }

  private didDisappear(): void {
    if (!this.disappearPending) return;
    this.disappearPending = false;
    this.around('viewDidDisappear', { animated: true });
  }

  // sources

  private static readonly eventSource: Partial<Record<LifecycleEvent, string>> = {
    viewWillAppear: 'navigation',
    viewIsAppearing: 'navigation',
    viewDidAppear: 'navigation',
    viewWillDisappear: 'navigation',
    viewDidDisappear: 'navigation',
    viewSafeAreaInsetsDidChange: 'insets',
    viewWillTransition: 'dimensions',
    traitCollectionDidChange: 'appearance',
    didReceiveMemoryWarning: 'memory',
  };

  private subscribeAll(): void {
    for (const event of Object.keys(LifecycleController.eventSource)) {
      if (this.registry.hasBlocksFor(event as LifecycleEvent)) this.subscribeFor(event as LifecycleEvent);
    }
  }

  private subscribeFor(event: LifecycleEvent): void {
    const name = LifecycleController.eventSource[event];
    if (!name || !this.attached || this.detached || this.removers.has(name)) return;
    const s = this.sources;
    switch (name) {
      case 'navigation':
        if (s.navigation) this.subscribeNavigation(s.navigation);
        break;
      case 'insets':
        if (s.safeAreaInsets) {
          this.lastInsets = s.safeAreaInsets.get();
          this.removers.set(name, toRemove(s.safeAreaInsets.subscribe((insets) => this.insetsChanged(insets))));
        }
        break;
      case 'dimensions':
        if (s.dimensions) {
          const w = s.dimensions.get('window');
          this.lastSize = { width: w.width, height: w.height };
          this.lastFontScale = w.fontScale;
          this.removers.set(name, toRemove(s.dimensions.addEventListener('change', (e) => this.dimensionsChanged(e.window))));
        }
        break;
      case 'appearance':
        if (s.appearance) {
          this.lastColorScheme = s.appearance.getColorScheme();
          this.removers.set(name, toRemove(s.appearance.addChangeListener((p) => this.colorSchemeChanged(p.colorScheme))));
          // The font scale arrives with the dimensions source.
          if (s.dimensions && !this.removers.has('dimensions')) this.subscribeFor('viewWillTransition');
        }
        break;
      case 'memory':
        if (s.appState && s.platform === 'ios') {
          this.removers.set(name, toRemove(s.appState.addEventListener('memoryWarning', () => this.around('didReceiveMemoryWarning'))));
        }
        break;
    }
  }

  private subscribeNavigation(nav: NonNullable<PlatformSources['navigation']>): void {
    const subs: Remove[] = [];
    subs.push(
      toRemove(
        nav.addListener('transitionStart', (e) => {
          if (e?.data?.closing) {
            this.disappearPending = true;
            this.around('viewWillDisappear', { animated: true });
          } else {
            this.appearPending = true;
            this.around('viewWillAppear', { animated: true });
          }
        }),
      ),
      toRemove(nav.addListener('focus', () => this.around('viewIsAppearing'))),
      toRemove(
        nav.addListener('transitionEnd', (e) => {
          if (e?.data?.closing) this.didDisappear();
          else this.didAppear();
        }),
      ),
    );
    this.removers.set('navigation', () => subs.forEach((r) => r()));
  }

  private insetsChanged(insets: Insets): void {
    if (this.lastInsets && sameInsets(this.lastInsets, insets)) return;
    const previousInsets = this.lastInsets;
    this.lastInsets = insets;
    this.around('viewSafeAreaInsetsDidChange', { previousInsets });
  }

  private dimensionsChanged(w: { width: number; height: number; fontScale?: number }): void {
    const size = { width: w.width, height: w.height };
    if (!this.lastSize || this.lastSize.width !== size.width || this.lastSize.height !== size.height) {
      this.lastSize = size;
      this.around('viewWillTransition', { size });
    }
    if (w.fontScale !== undefined && w.fontScale !== this.lastFontScale) {
      const previousFontScale = this.lastFontScale;
      this.lastFontScale = w.fontScale;
      this.around('traitCollectionDidChange', { previousFontScale, previousColorScheme: this.lastColorScheme });
    }
  }

  private colorSchemeChanged(colorScheme: string | null | undefined): void {
    const previousColorScheme = this.lastColorScheme;
    this.lastColorScheme = colorScheme;
    this.around('traitCollectionDidChange', { previousColorScheme, previousFontScale: this.lastFontScale });
  }
}
