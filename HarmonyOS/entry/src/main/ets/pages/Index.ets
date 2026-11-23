import { hilog } from '@kit.PerformanceAnalysisKit';
import { CYLLifecycleBridge, LifecycleEvent } from 'cyldeallocblockexecutor';
import EntryAbility from '../entryability/EntryAbility';

@Entry
@Component
struct Index {
  @State lines: string = '';
  private bridge: CYLLifecycleBridge<Object> = new CYLLifecycleBridge<Object>(this);
  private count: number = 0;

  private record(name: string): void {
    this.count += 1;
    // hilog is the machine-readable result; the screen shows it to the person looking.
    hilog.info(0x0000, 'CYL', 'EVENT %{public}d %{public}s', this.count, name);
    this.lines = this.lines + this.count.toString() + ' ' + name + '\n';
  }

  aboutToAppear(): void {
    const names: string[] = ['willMoveToParent', 'viewDidLoad', 'didMoveToParent', 'viewWillAppear',
      'viewIsAppearing', 'viewDidAppear', 'viewWillDisappear', 'viewDidDisappear', 'viewDidLayoutSubviews',
      'viewWillTransition', 'viewSafeAreaInsetsDidChange', 'traitCollectionDidChange', 'didReceiveMemoryWarning',
      'willMoveToWindow', 'didMoveToWindow'];
    for (const n of names) {
      this.bridge.controller.registry.addLifecycleCallback(n as LifecycleEvent, () => this.record(n));
    }
    this.bridge.controller.registry.addDeallocCallback(() => this.record('teardown'));
    this.bridge.aboutToAppear();
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
      Text(this.lines).fontSize(14).margin(16)
    }
    .width('100%').height('100%')
    .onAreaChange((o: Area, n: Area) => {
      this.bridge.onAreaChange({ width: Number(n.width), height: Number(n.height) },
        { width: Number(n.width), height: Number(n.height) });
    })
  }
}
