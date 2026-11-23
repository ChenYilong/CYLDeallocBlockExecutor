import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';
import { LifecycleController, LifecycleRegistry } from '../src/index.ts';
import type { LifecycleEvent, LifecycleTiming } from '../src/index.ts';

let owner: object;
let c: LifecycleController<object>;
let log: string[];

beforeEach(() => {
  owner = {};
  c = new LifecycleController(owner);
  log = [];
});

const on = (event: LifecycleEvent, timing: LifecycleTiming = 'afterSuper') =>
  c.registry.addLifecycleCallback(event, (_o, _id, info) => log.push(`${event}/${info.timing}`), { timing });

test('aboutToAppear: move and load events, once', () => {
  on('willMoveToParent');
  on('viewDidLoad', 'beforeSuper');
  on('didMoveToParent');
  c.aboutToAppear();
  c.aboutToAppear();
  assert.deepEqual(log, ['willMoveToParent/afterSuper', 'viewDidLoad/beforeSuper', 'didMoveToParent/afterSuper']);
});

test('onPageShow and onPageHide: appear and disappear order, no double fire', () => {
  for (const e of ['viewWillAppear', 'viewIsAppearing', 'viewDidAppear', 'viewWillDisappear', 'viewDidDisappear'] as const) on(e);
  c.onPageShow();
  c.onPageShow();
  c.onPageHide();
  c.onPageHide();
  assert.deepEqual(log.map((l) => l.split('/')[0]), [
    'viewWillAppear', 'viewIsAppearing', 'viewDidAppear', 'viewWillDisappear', 'viewDidDisappear',
  ]);
});

test('a page shown again appears again', () => {
  on('viewWillAppear');
  c.onPageShow();
  c.onPageHide();
  c.onPageShow();
  assert.equal(log.length, 2);
});

test('onAreaChange: layout every time, transition only when the size changed', () => {
  c.registry.addLifecycleCallback('viewWillTransition', (_o, _i, info) => log.push(`size ${info.size?.width}x${info.size?.height}`));
  on('viewDidLayoutSubviews');
  c.onAreaChange({ width: 0, height: 0 }, { width: 100, height: 200 });
  c.onAreaChange({ width: 100, height: 200 }, { width: 100, height: 200 });
  c.onAreaChange({ width: 100, height: 200 }, { width: 200, height: 100 });
  assert.deepEqual(log, [
    'size 100x200', 'viewDidLayoutSubviews/afterSuper',
    'viewDidLayoutSubviews/afterSuper',
    'size 200x100', 'viewDidLayoutSubviews/afterSuper',
  ]);
});

test('viewDidLayoutSubviews: invoke once and re-arm', () => {
  c.registry.addLifecycleCallback('viewDidLayoutSubviews', () => log.push('once'), { invokeOnce: true, key: 'layout' });
  c.onAreaChange({ width: 0, height: 0 }, { width: 1, height: 1 });
  c.onAreaChange({ width: 1, height: 1 }, { width: 1, height: 1 });
  c.registry.rearmLifecycleCallback('layout');
  c.onAreaChange({ width: 1, height: 1 }, { width: 1, height: 1 });
  assert.deepEqual(log, ['once', 'once']);
});

test('avoid area change carries the previous insets and skips equal ones', () => {
  c.registry.addLifecycleCallback('viewSafeAreaInsetsDidChange', (_o, _i, info) => log.push(info.previousInsets ? JSON.stringify(info.previousInsets) : 'none'));
  c.avoidAreaChanged({ top: 47, left: 0, bottom: 34, right: 0 });
  c.avoidAreaChanged({ top: 47, left: 0, bottom: 34, right: 0 });
  c.avoidAreaChanged({ top: 24, left: 0, bottom: 0, right: 0 });
  assert.deepEqual(log, ['none', '{"top":47,"left":0,"bottom":34,"right":0}']);
});

test('color mode change carries the previous mode; the first report is only recorded', () => {
  c.registry.addLifecycleCallback('traitCollectionDidChange', (_o, _i, info) => log.push(String(info.previousColorScheme)));
  c.colorModeChanged('light');
  c.colorModeChanged('light');
  c.colorModeChanged('dark');
  assert.deepEqual(log, ['light']);
});

test('memory level: only the critical level fires', () => {
  on('didReceiveMemoryWarning');
  c.memoryLevel(0);
  c.memoryLevel(1);
  c.memoryLevel(2);
  assert.equal(log.length, 1);
});

test('aboutToDisappear: hides, moves, then runs teardown blocks in order, once', () => {
  on('viewDidDisappear');
  on('didMoveToParent');
  c.registry.addDeallocCallback((_o, id, info) => log.push(`dealloc ${info.isDealloc}`));
  c.onPageShow();
  c.aboutToDisappear();
  c.aboutToDisappear();
  assert.deepEqual(log, ['viewDidDisappear/afterSuper', 'didMoveToParent/afterSuper', 'dealloc true']);
});

test('isDetached is true after aboutToDisappear', () => {
  assert.equal(c.isDetached, false);
  c.aboutToDisappear();
  assert.equal(c.isDetached, true);
});

test('a hidden page does not appear after teardown', () => {
  on('viewWillAppear');
  c.aboutToDisappear();
  c.onPageShow();
  assert.equal(log.length, 0);
});

test('manual end beside automatic afterSuper (layout block)', () => {
  c.registry.setManualLifecycleDispatch(true, ['viewDidLayoutSubviews'], ['end']);
  on('viewDidLayoutSubviews');
  on('viewDidLayoutSubviews', 'end');
  c.onAreaChange({ width: 0, height: 0 }, { width: 1, height: 1 });
  assert.deepEqual(log, ['viewDidLayoutSubviews/afterSuper']);
  c.registry.invokeLifecycleCallbacks('viewDidLayoutSubviews', 'end');
  assert.equal(log.length, 2);
});

test('the registry is shared with the owner', () => {
  assert.equal(LifecycleRegistry.of(owner), c.registry);
});

test('window attach and detach fire the window moves with the window', () => {
  c.registry.addLifecycleCallback('willMoveToWindow', (_o, _i, info) => log.push(`will ${info.window === null ? 'null' : 'window'}`));
  c.registry.addLifecycleCallback('didMoveToWindow', (_o, _i, info) => log.push(`did ${info.window === null ? 'null' : 'window'}`));
  c.windowAttached({});
  c.windowDetached();
  assert.deepEqual(log, ['will window', 'did window', 'will null', 'did null']);
});

test('screen: onPageShow / onPageHide and onVisibleAreaChange report transitions only', () => {
  on('didEnterScreen');
  on('didLeaveScreen');
  c.onPageShow();
  c.visibleAreaChanged(true);
  c.visibleAreaChanged(false);
  c.visibleAreaChanged(false);
  c.onPageHide();
  assert.deepEqual(log, ['didEnterScreen/afterSuper', 'didLeaveScreen/afterSuper']);
});

test('scroll start and stop fire begin, end drag without deceleration and end scrolling', () => {
  for (const e of ['scrollWillBeginDragging', 'scrollDidEndDragging', 'scrollDidEndScrolling'] as const) {
    c.registry.addLifecycleCallback(e, (_o, _i, info) => log.push(`${e}${info.willDecelerate === undefined ? '' : ' ' + info.willDecelerate}`));
  }
  c.scrollStarted();
  c.scrollStopped();
  assert.deepEqual(log, ['scrollWillBeginDragging', 'scrollDidEndDragging false', 'scrollDidEndScrolling']);
});
