import { window } from '@kit.ArkUI';
import { LifecycleController, ConfigSnapshot } from './LifecycleController';
import { Insets } from './Types';

/**
 * Feeds a `LifecycleController` from the real ArkUI and ability callbacks.
 * The component forwards its own callbacks, one line each:
 *
 * ```ts
 * @Component struct Page {
 *   private bridge: CYLLifecycleBridge<Object> = new CYLLifecycleBridge<Object>(this);
 *   aboutToAppear() { this.bridge.aboutToAppear(); }
 *   onPageShow() { this.bridge.onPageShow(); }
 *   onPageHide() { this.bridge.onPageHide(); }
 *   aboutToDisappear() { this.bridge.aboutToDisappear(); }
 *   build() { Column() {}.onAreaChange(() => this.bridge.onAreaChange()) }
 * }
 * ```
 *
 * `attachWindow(win)` subscribes the window size and avoid-area events;
 * the ability forwards `onConfigurationUpdate` and `onMemoryLevel`.
 * Blocks go on `bridge.controller.registry`, before `aboutToAppear` for the
 * `viewDidLoad` blocks.
 */
export class CYLLifecycleBridge<T extends Object> {
  readonly controller: LifecycleController<T>;
  private win: window.Window | undefined;
  private sizeListener: ((size: window.Size) => void) | undefined;
  private avoidListener: ((data: window.AvoidAreaOptions) => void) | undefined;
  private timer: number = -1;

  constructor(owner: T) {
    this.controller = new LifecycleController<T>(owner);
  }

  aboutToAppear(): void {
    this.controller.create();
  }

  onPageShow(): void {
    this.controller.show();
    this.timer = setTimeout(() => this.controller.resumedAndDrawn(), 0);
  }

  onPageHide(): void {
    this.controller.hide();
  }

  onAreaChange(): void {
    this.controller.layout();
  }

  /** The ability's `onMemoryLevel(level)`. */
  onMemoryLevel(level: number): void {
    this.controller.memoryLevel(level);
  }

  /** The ability's `onConfigurationUpdate`, with the current window size. */
  onConfigurationUpdate(colorMode: number, fontScale: number, width: number, height: number): void {
    const config: ConfigSnapshot = { width: width, height: height, colorMode: colorMode, fontScale: fontScale };
    this.controller.configurationChanged(config);
  }

  /** Subscribes the window's size and avoid-area events; removed in `aboutToDisappear`. */
  attachWindow(win: window.Window, colorMode: number, fontScale: number): void {
    this.detachWindow();
    this.win = win;
    try {
      const rect = win.getWindowProperties().windowRect;
      this.controller.configurationChanged({ width: rect.width, height: rect.height, colorMode: colorMode, fontScale: fontScale });
    } catch (e) {
      // No window properties yet: the first size event becomes the baseline.
    }
    this.sizeListener = (size: window.Size): void => {
      this.controller.configurationChanged({ width: size.width, height: size.height, colorMode: colorMode, fontScale: fontScale });
    };
    this.avoidListener = (_data: window.AvoidAreaOptions): void => {
      try {
        const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const insets: Insets = {
          top: area.topRect.height,
          left: area.leftRect.width,
          bottom: area.bottomRect.height,
          right: area.rightRect.width,
        };
        this.controller.insetsChanged(insets);
      } catch (e) {
        // The avoid area could not be read: keep the previous insets.
      }
    };
    win.on('windowSizeChange', this.sizeListener);
    win.on('avoidAreaChange', this.avoidListener);
  }

  private detachWindow(): void {
    if (this.win !== undefined) {
      if (this.sizeListener !== undefined) this.win.off('windowSizeChange', this.sizeListener);
      if (this.avoidListener !== undefined) this.win.off('avoidAreaChange', this.avoidListener);
    }
    this.win = undefined;
    this.sizeListener = undefined;
    this.avoidListener = undefined;
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) clearTimeout(this.timer);
    this.detachWindow();
    this.controller.destroy();
  }
}
