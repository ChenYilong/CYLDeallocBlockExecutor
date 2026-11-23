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
 * - appear and disappear: navigation `focus` / `blur` / `transitionStart` /
 *   `transitionEnd` (see `ControllerOptions.navigation`); the will, isAppearing
 *   and did events keep their order whichever arrives first. App foreground
 *   and background never feed an appear event (as on iOS);
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
export interface ControllerOptions {
  /**
   * How appear and disappear arrive. `stack` (default): `focus` / `blur` open
   * the will events, `transitionStart` / `transitionEnd` close them with the did
   * events (stack and native-stack navigators). `immediate`: there is no
   * transition to wait for (tab navigators without animation), so `focus` fires
   * will, isAppearing and did back to back and `blur` fires will and did
   * disappear.
   */
  navigation?: 'stack' | 'immediate';
}

export class LifecycleController<T extends object> {
  readonly registry: LifecycleRegistry;
  private readonly owner: T;
  private readonly sources: PlatformSources;
  private readonly removers = new Map<string, Remove>();
  private attached = false;
  private detached = false;
  private readonly mode: 'stack' | 'immediate';
  // appear: idle -> will -> is -> did; disappear: idle -> will -> did
  private appear: 'idle' | 'will' | 'is' | 'did' = 'idle';
  private disappear: 'idle' | 'will' | 'did' = 'idle';
  private lastColorScheme: string | null | undefined;
  private lastFontScale: number | undefined;
  private lastInsets: Insets | undefined;
  private lastSize: { width: number; height: number } | undefined;
  private onScreen = false;
  private dragging = false;
  private decelerating = false;

  constructor(owner: T, sources: PlatformSources = {}, options: ControllerOptions = {}) {
    this.owner = owner;
    this.mode = options.navigation ?? 'stack';
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

  // Screen and scrolling (design v5)

  /**
   * Reports whether the owner is visible on screen. Appear and disappear events report it by themselves (right after
   * `viewDidAppear` / `viewDidDisappear`); call this for a view that scrolls in and out (a list item, from
   * `onViewableItemsChanged`). Fires `didEnterScreen` / `didLeaveScreen` on transitions only.
   */
  setScreenVisible(visible: boolean): void {
    if (this.onScreen === visible || this.detached) return;
    this.onScreen = visible;
    this.around(visible ? 'didEnterScreen' : 'didLeaveScreen');
  }

  /** Spread onto the owner's `ScrollView` / `FlatList`: the scroll events of design v5, without taking over any prop you set yourself. */
  readonly scrollHandlers = {
    onScrollBeginDrag: (event?: any): void => {
      this.dragging = true;
      this.around('scrollWillBeginDragging', { scrollView: event?.nativeEvent ?? event });
    },
    onScrollEndDrag: (event?: any): void => {
      const v = event?.nativeEvent?.velocity;
      const willDecelerate = v !== undefined && (Math.abs(v.x ?? 0) > 0 || Math.abs(v.y ?? 0) > 0);
      this.dragging = false;
      this.decelerating = willDecelerate;
      this.around('scrollDidEndDragging', { scrollView: event?.nativeEvent ?? event, willDecelerate });
      if (!willDecelerate) this.around('scrollDidEndScrolling', { scrollView: event?.nativeEvent ?? event });
    },
    onMomentumScrollBegin: (_event?: any): void => {
      this.decelerating = true;
    },
    onMomentumScrollEnd: (event?: any): void => {
      if (!this.decelerating && !this.dragging) return;
      this.decelerating = false;
      if (!this.dragging) this.around('scrollDidEndScrolling', { scrollView: event?.nativeEvent ?? event });
    },
  };

  /** The `onLayout` handler of the owner's view. */
  onLayout = (_event?: unknown): void => {
    this.around('viewDidLayoutSubviews');
  };

  private flushPending(): void {
    if (this.appear === 'will' || this.appear === 'is') this.didAppear();
    if (this.disappear === 'will') this.didDisappear();
  }

  // The appear and disappear sequences keep their order whichever source
  // arrives first (`focus` before or after `transitionStart`).
  private willAppear(): void {
    if (this.appear !== 'idle') return;
    this.disappear = 'idle';
    this.appear = 'will';
    this.around('viewWillAppear', { animated: this.mode === 'stack' });
  }

  private isAppearing(): void {
    this.willAppear();
    if (this.appear !== 'will') return;
    this.appear = 'is';
    this.around('viewIsAppearing');
  }

  private didAppear(): void {
    this.isAppearing();
    if (this.appear !== 'is') return;
    this.appear = 'did';
    this.around('viewDidAppear', { animated: this.mode === 'stack' });
    this.setScreenVisible(true);
  }

  private willDisappear(): void {
    if (this.disappear !== 'idle') return;
    this.appear = 'idle';
    this.disappear = 'will';
    this.around('viewWillDisappear', { animated: this.mode === 'stack' });
  }

  private didDisappear(): void {
    this.willDisappear();
    if (this.disappear !== 'will') return;
    this.disappear = 'did';
    this.around('viewDidDisappear', { animated: this.mode === 'stack' });
    this.setScreenVisible(false);
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
    const stack = this.mode === 'stack';
    subs.push(
      toRemove(
        nav.addListener('focus', () => {
          this.willAppear();
          this.isAppearing();
          if (!stack) this.didAppear();
        }),
      ),
      toRemove(
        nav.addListener('blur', () => {
          this.willDisappear();
          if (!stack) this.didDisappear();
        }),
      ),
    );
    if (stack) {
      // `data.closing` is true when the screen leaves; tab navigators send no data and only target the screen that opens.
      subs.push(
        toRemove(nav.addListener('transitionStart', (e) => (e?.data?.closing ? this.willDisappear() : this.willAppear()))),
        toRemove(nav.addListener('transitionEnd', (e) => (e?.data?.closing ? this.didDisappear() : this.didAppear()))),
      );
    }
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

/**
 * Mounts a controller for `owner` and returns the unmount function. Every mount
 * makes a new controller on the owner's shared registry, so mount, unmount,
 * mount (React StrictMode in development does exactly this) subscribes again.
 * The first unmount runs the teardown blocks, which then no longer exist.
 */
export function mountLifecycle<T extends object>(
  owner: T,
  sources: PlatformSources = {},
  options: ControllerOptions = {},
): { controller: LifecycleController<T>; unmount: () => void } {
  const controller = new LifecycleController(owner, sources, options);
  controller.attach();
  return { controller, unmount: () => controller.detach() };
}
