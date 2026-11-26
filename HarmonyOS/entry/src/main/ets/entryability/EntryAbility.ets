import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  static win: window.Window | undefined = undefined;
  static memoryHook: ((level: number) => void) | undefined = undefined;
  static colorHook: ((mode: number) => void) | undefined = undefined;
  static terminate: (() => void) | undefined = undefined;
  static initialColorMode: number | undefined = undefined;
  static setColor: ((mode: ConfigurationConstant.ColorMode) => void) | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'CYL', 'onCreate');
    EntryAbility.initialColorMode = this.context.config.colorMode as number | undefined;
    EntryAbility.terminate = (): void => { this.context.terminateSelf(); };
    EntryAbility.setColor = (mode: ConfigurationConstant.ColorMode): void => { this.context.getApplicationContext().setColorMode(mode); };
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((win: window.Window) => {
      EntryAbility.win = win;
    }).catch((err: BusinessError) => {
      hilog.error(0x0000, 'CYL', 'getMainWindow failed %{public}s', JSON.stringify(err));
    });
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'CYL', 'loadContent failed %{public}s', JSON.stringify(err));
      }
    });
  }

  /**
   * The single code path for a memory level: the system callback below and the demo page's debug button both call it,
   * so the button exercises exactly what a real delivery would.
   */
  static deliverMemoryLevel(level: number): void {
    hilog.info(0x0000, 'CYL', 'deliverMemoryLevel level=%{public}d', level);
    if (EntryAbility.memoryHook !== undefined) EntryAbility.memoryHook(level);
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    EntryAbility.deliverMemoryLevel(level);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // Read the delivered configuration: this.context.config still holds the previous one while the callback runs.
    // ConfigurationConstant.ColorMode: 0 dark, 1 light.
    const mode = newConfig.colorMode;
    hilog.info(0x0000, 'CYL', 'onConfigurationUpdate colorMode=%{public}d', mode as number);
    if (EntryAbility.colorHook !== undefined && mode !== undefined) EntryAbility.colorHook(mode as number);
  }

  /**
   * The system Back key. `true` (the default since API 12) only moves the ability to the background, so the page is never
   * destroyed and no teardown block runs; `false` destroys the ability: aboutToDisappear runs and the bridge tears down.
   */
  onBackPressed(): boolean {
    hilog.info(0x0000, 'CYL', 'onBackPressed -> false (destroy)');
    return false;
  }
}
