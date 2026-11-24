import { hilog } from '@kit.PerformanceAnalysisKit';
import { CYLLifecycleBridge, LifecycleEvent } from 'cyldeallocblockexecutor';
import EntryAbility from '../entryability/EntryAbility';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State lines: string = '';
  private bridge: CYLLifecycleBridge<Object> = new CYLLifecycleBridge<Object>(this);
  private count: number = 0;
  private rows: number[] = Array.from({ length: 120 }, (_: number, i: number) => i);

  private record(name: string): void {
    this.count += 1;
    // hilog is the machine-readable result; the screen shows it to the person looking.
    hilog.info(0x0000, 'CYL', 'EVENT %{public}d %{public}s', this.count, name);
    const all: string[] = ((this.lines === '' ? '' : this.lines + '\n') + this.count.toString() + ' ' + name).split('\n');
    this.lines = all.slice(-10).join('\n');
  }

  aboutToAppear(): void {
    const names: string[] = ['willMoveToParent', 'viewDidLoad', 'didMoveToParent', 'viewWillAppear',
      'viewIsAppearing', 'viewDidAppear', 'viewWillDisappear', 'viewDidDisappear', 'viewDidLayoutSubviews',
      'viewWillTransition', 'viewSafeAreaInsetsDidChange', 'traitCollectionDidChange', 'didReceiveMemoryWarning',
      'willMoveToWindow', 'didMoveToWindow', 'scrollWillBeginDragging', 'scrollDidEndDragging', 'scrollDidEndScrolling'];
    for (const n of names) {
      this.bridge.controller.registry.addLifecycleCallback(n as LifecycleEvent, () => this.record(n));
    }
    this.bridge.controller.registry.addDeallocCallback(() => this.record('teardown'));
    this.bridge.aboutToAppear(EntryAbility.initialColorMode);
    EntryAbility.memoryHook = (level: number): void => this.bridge.onMemoryLevel(level);
    EntryAbility.colorHook = (mode: number): void => this.bridge.onConfigurationUpdate(mode);
    if (EntryAbility.win !== undefined) this.bridge.attachWindow(EntryAbility.win);
  }

  onPageShow(): void {
    this.bridge.onPageShow();
  }

  onPageHide(): void {
    this.bridge.onPageHide();
  }

  aboutToDisappear(): void {
    this.bridge.aboutToDisappear();
  }

  build() {
    Column() {
      Text('CYLLifecycleBridge on device').fontSize(20).margin({ top: 60 })
      Row() {
        Button('Close').onClick(() => { if (EntryAbility.terminate !== undefined) EntryAbility.terminate(); })
        Button('Dark').onClick(() => { if (EntryAbility.setColor !== undefined) EntryAbility.setColor(ConfigurationConstant.ColorMode.COLOR_MODE_DARK); })
        Button('Light').onClick(() => { if (EntryAbility.setColor !== undefined) EntryAbility.setColor(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT); })
        Button('Land').onClick(() => { if (EntryAbility.win !== undefined) EntryAbility.win.setPreferredOrientation(window.Orientation.LANDSCAPE); })
        Button('Port').onClick(() => { if (EntryAbility.win !== undefined) EntryAbility.win.setPreferredOrientation(window.Orientation.PORTRAIT); })
      }
      Text(this.lines).fontSize(12).margin(8).height(150)
      List() {
        ForEach(this.rows, (i: number) => {
          ListItem() {
            Text('Row ' + i.toString()).fontSize(18).width('100%').height(56).padding(12)
          }
        })
      }
      .layoutWeight(1)
      .onScrollStart(() => this.bridge.controller.scrollStarted())
      .onScrollStop(() => this.bridge.controller.scrollStopped())
    }
    .width('100%').height('100%')
    .onAreaChange((o: Area, n: Area) => {
      this.bridge.onAreaChange({ width: Number(n.width), height: Number(n.height) },
        { width: Number(n.width), height: Number(n.height) });
    })
  }
}
