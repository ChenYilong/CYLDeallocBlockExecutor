import { LifecycleRegistry } from './LifecycleRegistry';
import type { Insets, LifecycleEvent, LifecycleInfo } from './Types';

/** The values of the configuration the controller compares between two changes. */
export interface ConfigSnapshot {
  width: number;
  height: number;
  colorMode: number;
  fontScale: number;
}

const sameInsets = (a: Insets, b: Insets): boolean =>
  a.top === b.top && a.left === b.left && a.bottom === b.bottom && a.right === b.right;

/**
 * Fires the lifecycle events of an owner (an ArkUI component or any object)
 * when the platform bridge calls its methods: the HarmonyOS counterpart of the
 * iOS `UIViewController` hook. It imports nothing from the OS, so it runs in
 * Node; `CYLLifecycleBridge.ets` feeds it from the real ArkUI callbacks.
 *
 * Mapping (iOS event: HarmonyOS source):
 * - `viewDidLoad`: `create()` (`aboutToAppear`);
 * - `viewWillAppear` and `viewIsAppearing`: `show()` (`onPageShow`), back to
 *   back; `viewDidAppear`: `resumedAndDrawn()` (the next macrotask after
 *   `onPageShow`);
 * - `viewWillDisappear` and `viewDidDisappear`: `hide()` (`onPageHide`), back
 *   to back (ArkUI has no split). A page shown again after the app returns from
 *   the background fires them again (unlike iOS);
 * - `viewDidLayoutSubviews`: `layout()` (`onAreaChange`, after layout);
 *   `viewWillLayoutSubviews` has no source;
 * - `viewSafeAreaInsetsDidChange`: `insetsChanged(insets)` (window
 *   `avoidAreaChange`);
 * - `viewWillTransition` and `traitCollectionDidChange`:
 *   `configurationChanged(snapshot)` (window size / color mode / font scale);
 * - `willMoveToParent` / `didMoveToParent`: `attach()` (with `create()`) and
 *   `destroy()`;
 * - `didReceiveMemoryWarning`: `memoryLevel(level)` (`onMemoryLevel`);
 * - `viewLayoutMarginsDidChange`: not available (no layout margins).
 * Teardown blocks run in `destroy()` (`aboutToDisappear`): deterministic for a
 * component, not a garbage-collection event.
 */
export class LifecycleController<T extends object> {
  readonly registry: LifecycleRegistry;
  private attached = false;
  private destroyed = false;
  private appearPending = false;
  private disappearPending = false;
  private lastInsets: Insets | undefined;
  private lastConfig: ConfigSnapshot | undefined;

  constructor(owner: T) {
    this.registry = LifecycleRegistry.of(owner);
    this.registry.hookInstalled = true;
  }

  private around(event: LifecycleEvent, info: Partial<LifecycleInfo> = {}): void {
    this.registry.fireAutomatic(event, 'beforeSuper', info);
    this.registry.fireAutomatic(event, 'afterSuper', info);
  }

  /** The owner was added to its parent. */
  attach(): void {
    if (this.attached) return;
    this.attached = true;
    this.around('willMoveToParent', { parentAttached: true });
    this.around('didMoveToParent', { parentAttached: true });
  }

  /** `aboutToAppear`: the owner exists and is about to build. */
  create(initialConfig?: ConfigSnapshot, initialInsets?: Insets): void {
    this.lastConfig = initialConfig ?? this.lastConfig;
    this.lastInsets = initialInsets ?? this.lastInsets;
    this.attach();
    this.around('viewDidLoad');
  }

  /** `onPageShow`. */
  show(): void {
    this.appearPending = true;
    this.around('viewWillAppear', { animated: false });
    this.around('viewIsAppearing');
  }

  /** The macrotask after `onPageShow`. */
  resumedAndDrawn(): void {
    if (!this.appearPending) return;
    this.appearPending = false;
    this.around('viewDidAppear');
  }

  /** `onPageHide`. */
  hide(): void {
    this.disappearPending = true;
    this.around('viewWillDisappear');
    this.stop();
  }

  private stop(): void {
    if (!this.disappearPending) return;
    this.disappearPending = false;
    this.around('viewDidDisappear');
  }

  /** `onAreaChange`: the component was laid out. */
  layout(): void {
    this.around('viewDidLayoutSubviews');
  }

  insetsChanged(insets: Insets): void {
    const previous = this.lastInsets;
    if (previous !== undefined && sameInsets(previous, insets)) return;
    this.lastInsets = insets;
    this.around('viewSafeAreaInsetsDidChange', { previousInsets: previous });
  }

  configurationChanged(config: ConfigSnapshot): void {
    const previous = this.lastConfig;
    this.lastConfig = config;
    if (previous === undefined) return;
    if (previous.width !== config.width || previous.height !== config.height) {
      this.around('viewWillTransition', { size: { width: config.width, height: config.height } });
    }
    if (previous.colorMode !== config.colorMode || previous.fontScale !== config.fontScale) {
      this.around('traitCollectionDidChange', {
        previousColorMode: previous.colorMode,
        previousFontScale: previous.fontScale,
      });
    }
  }

  memoryLevel(level: number): void {
    this.around('didReceiveMemoryWarning', { memoryLevel: level });
  }

  /** The owner goes away: pending did events, the move events, then the teardown blocks. */
  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.resumedAndDrawn();
    this.stop();
    this.around('willMoveToParent', { parentAttached: false });
    this.around('didMoveToParent', { parentAttached: false });
    this.registry.runDealloc();
  }
}
