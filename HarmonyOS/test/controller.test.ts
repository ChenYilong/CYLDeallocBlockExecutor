import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';
import { LifecycleController } from '../cyllifecycle/src/main/ets/LifecycleController';
import type { LifecycleEvent } from '../cyllifecycle/src/main/ets/Types';

// The controller is driven the way CYLLifecycleBridge.ets drives it: Node only, no emulator run.
let owner: object;
let c: LifecycleController<object>;
let log: string[];

beforeEach(() => { owner = {}; c = new LifecycleController(owner); log = []; });

function watch(...events: LifecycleEvent[]) {
  for (const ev of events) for (const t of ['beforeSuper', 'afterSuper'] as const) {
    c.registry.addLifecycleCallback(ev, () => log.push(`${ev}/${t}`), { timing: t });
  }
}
const after = () => log.filter((l) => l.endsWith('afterSuper')).map((l) => l.split('/')[0]);

test('create fires move and load events with timings; destroy fires move with parentAttached false', () => {
  const attached: Array<boolean | undefined> = [];
  watch('willMoveToParent', 'viewDidLoad', 'didMoveToParent');
  c.registry.addLifecycleCallback('willMoveToParent', (_o, _i, info) => attached.push(info.parentAttached));
  c.create();
  assert.deepEqual(log, [
    'willMoveToParent/beforeSuper', 'willMoveToParent/afterSuper', 'didMoveToParent/beforeSuper',
    'didMoveToParent/afterSuper', 'viewDidLoad/beforeSuper', 'viewDidLoad/afterSuper',
  ]);
  c.destroy();
  assert.deepEqual(attached, [true, false]);
});

test('show fires will and isAppearing, the next macrotask fires did; hide fires will and did disappear', () => {
  watch('viewWillAppear', 'viewIsAppearing', 'viewDidAppear', 'viewWillDisappear', 'viewDidDisappear');
  c.show();
  assert.deepEqual(after(), ['viewWillAppear', 'viewIsAppearing']);
  c.resumedAndDrawn();
  assert.deepEqual(after(), ['viewWillAppear', 'viewIsAppearing', 'viewDidAppear']);
  log.length = 0;
  c.hide();
  assert.deepEqual(after(), ['viewWillDisappear', 'viewDidDisappear']);
});

test('foreground and background fire the appear events again (differs from iOS)', () => {
  watch('viewWillAppear');
  c.show(); c.hide(); c.show();
  assert.deepEqual(after(), ['viewWillAppear', 'viewWillAppear']);
});

test('a pending did event is flushed on destroy', () => {
  watch('viewDidAppear');
  c.show();
  c.destroy();
  assert.deepEqual(after(), ['viewDidAppear']);
});

test('layout fires viewDidLayoutSubviews with invoke once and re-arm', () => {
  c.registry.addLifecycleCallback('viewDidLayoutSubviews', () => log.push('layout'), { invokeOnce: true });
  c.layout(); c.layout();
  assert.deepEqual(log, ['layout']);
  c.registry.rearmLifecycleCallbacks('viewDidLayoutSubviews');
  c.layout();
  assert.deepEqual(log, ['layout', 'layout']);
});

test('insets with the previous insets; unchanged insets do not fire', () => {
  const seen: unknown[] = [];
  c.create(undefined, { top: 0, left: 0, bottom: 0, right: 0 });
  c.registry.addLifecycleCallback('viewSafeAreaInsetsDidChange', (_o, _i, info) => seen.push(info.previousInsets));
  c.insetsChanged({ top: 0, left: 0, bottom: 0, right: 0 });
  assert.deepEqual(seen, []);
  c.insetsChanged({ top: 47, left: 0, bottom: 34, right: 0 });
  assert.deepEqual(seen, [{ top: 0, left: 0, bottom: 0, right: 0 }]);
});

test('configuration: size feeds viewWillTransition, color mode and font scale feed traitCollectionDidChange', () => {
  const sizes: unknown[] = [];
  const prev: unknown[] = [];
  c.create({ width: 400, height: 800, colorMode: 0, fontScale: 1 });
  c.registry.addLifecycleCallback('viewWillTransition', (_o, _i, info) => sizes.push(info.size));
  c.registry.addLifecycleCallback('traitCollectionDidChange', (_o, _i, info) => prev.push([info.previousColorMode, info.previousFontScale]));
  c.configurationChanged({ width: 800, height: 400, colorMode: 0, fontScale: 1 });
  assert.deepEqual(sizes, [{ width: 800, height: 400 }]);
  assert.deepEqual(prev, []);
  c.configurationChanged({ width: 800, height: 400, colorMode: 1, fontScale: 1.3 });
  assert.deepEqual(prev, [[0, 1]]);
  assert.equal(sizes.length, 1);
});

test('memory level fires didReceiveMemoryWarning with the level', () => {
  const levels: unknown[] = [];
  c.registry.addLifecycleCallback('didReceiveMemoryWarning', (_o, _i, info) => levels.push(info.memoryLevel));
  c.memoryLevel(2);
  assert.deepEqual(levels, [2]);
});

test('destroy runs teardown blocks in order, once; destroy twice is harmless', () => {
  c.registry.addDeallocCallback(() => log.push('a'));
  c.registry.addDeallocCallback(() => log.push('b'));
  c.destroy(); c.destroy();
  assert.deepEqual(log, ['a', 'b']);
});

test('manual end beside automatic afterSuper', () => {
  c.registry.setManualLifecycleDispatch(true, ['viewDidLayoutSubviews'], ['end']);
  c.registry.addLifecycleCallback('viewDidLayoutSubviews', () => log.push('end-block'), { timing: 'end', key: 'cyl.core.layoutBlock', invokeOnce: true });
  c.registry.addLifecycleCallback('viewDidLayoutSubviews', () => log.push('after'));
  c.layout();
  assert.deepEqual(log, ['after']);
  c.registry.invokeLifecycleCallbacks('viewDidLayoutSubviews', 'end');
  assert.deepEqual(log, ['after', 'end-block']);
});
