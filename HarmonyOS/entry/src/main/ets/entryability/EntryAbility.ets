import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  static win: window.Window | undefined = undefined;
  static memoryHook: ((level: number) => void) | undefined = undefined;
  static colorHook: ((mode: number) => void) | undefined = undefined;
  static terminate: (() => void) | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'CYL', 'onCreate');
    EntryAbility.terminate = (): void => { this.context.terminateSelf(); };
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((win: window.Window) => {
      EntryAbility.win = win;
    });
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'CYL', 'loadContent failed %{public}s', JSON.stringify(err));
      }
    });
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    if (EntryAbility.memoryHook !== undefined) EntryAbility.memoryHook(level);
  }

  onConfigurationUpdate(config: Object): void {
    // ConfigurationConstant.ColorMode: 0 dark, 1 light.
    const mode = this.context.config.colorMode;
    if (EntryAbility.colorHook !== undefined && mode !== undefined) EntryAbility.colorHook(mode as number);
  }
}
