// [EN] Unit tests of CYLLifecycleCallbacks, the HarmonyOS port of the callback registry: the same cases as the Kotlin
//      CYLLifecycleCallbacksTest and the checks of Tests/LifecycleTests/main.swift that apply on HarmonyOS
//      (docs/Lifecycle-Callbacks.md maps each one). The registry is plain TypeScript without ArkUI imports, so Node runs it
//      (type stripping, Node 22.18+): node --test harmonyos/cyldeallocblockexecutor/test/*.test.mjs
// [CN] CYLLifecycleCallbacks（回调注册表的鸿蒙移植）的单元测试：用例与 Kotlin 的 CYLLifecycleCallbacksTest 以及 Tests/LifecycleTests/main.swift 中适用于鸿蒙的检查相同
//      （docs/Lifecycle-Callbacks.md 逐项对照）。注册表是不含 ArkUI 导入的纯 TypeScript，所以可以用 Node（类型擦除，Node 22.18+）运行。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CYLLifecycleCallbacks, CYLLifecycleEvent, CYLLifecycleInfo, cylLifecycleEventName, cylDeallocCallbackIllegalIdentifier,
} from '../src/main/ets/CYLLifecycleCallbacks.ts';

const E = CYLLifecycleEvent;
const noop = () => {};

test('identifiers ascend from one, never zero', () => {
  const registry = new CYLLifecycleCallbacks({});
  const ids = [0, 1, 2].map(() => registry.willDealloc(noop));
  assert.deepEqual(ids, [1, 2, 3]);
  assert.ok(!ids.includes(cylDeallocCallbackIllegalIdentifier));
});

test('cancel returns true once, then false; cancel(0) is false', () => {
  const registry = new CYLLifecycleCallbacks({});
  const ids = [0, 1, 2].map(() => registry.willDealloc(noop));
  assert.equal(registry.cancel(ids[1]), true);
  assert.equal(registry.cancel(ids[1]), false);
  assert.equal(registry.cancel(cylDeallocCallbackIllegalIdentifier), false);
});

test('cancelled later tasks do not run, the earlier one does', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  const ids = ['first', 'second', 'third'].map((name) => registry.willDealloc(() => log.push(name)));
  assert.deepEqual(ids.filter((id) => id > ids[0]).map((id) => registry.cancel(id)), [true, true]);
  registry.dealloc();
  assert.deepEqual(log, ['first']);
});

test('adding willDealloc runs nothing early, each runs once, in order', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  for (const name of ['a', 'b', 'c']) {
    registry.willDealloc(() => log.push(name));
    assert.deepEqual(log, []);
  }
  registry.dealloc();
  assert.deepEqual(log, ['a', 'b', 'c']);
});

test('order by identifier, cancel one, typed owner', () => {
  const owner = { name: 'owner' };
  const registry = new CYLLifecycleCallbacks(owner);
  const log = [];
  let typed = false;
  const ids = [0, 1, 2].map((index) => registry.addCallback(E.PAGE_SHOW, (received, id) => {
    typed = received === owner;
    log.push(index + ':' + id);
  }));
  registry.cancel(ids[1]);
  registry.perform(E.PAGE_SHOW);
  assert.deepEqual(log, ['0:' + ids[0], '2:' + ids[2]]);
  assert.ok(typed);
});

test('cancelAll removes the unkeyed callbacks of the event', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.PAGE_SHOW, () => log.push('show'));
  registry.addCallback(E.PAGE_HIDE, () => log.push('hide'));
  registry.cancelAll(E.PAGE_SHOW);
  registry.perform(E.PAGE_SHOW);
  registry.perform(E.PAGE_HIDE);
  assert.deepEqual(log, ['hide']);
});

test('invokeOnce runs once until rearmed by key', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('end1'), true, 'layoutBlock');
  registry.perform(E.LAYOUT);
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['end1']);
  assert.equal(registry.rearm('layoutBlock'), true);
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['end1', 'end1']);
  assert.equal(registry.rearm('unknown'), false);
});

test('replace by key re-arms the replacement', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('end1'), true, 'layoutBlock');
  registry.perform(E.LAYOUT);
  log.length = 0;
  registry.addCallback(E.LAYOUT, () => log.push('end2'), true, 'layoutBlock');
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['end2']);
});

test('the core re-arms by key, the app run-once block stays fired', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('core'), true, 'cyl.core.layoutBlock');
  registry.addCallback(E.LAYOUT, () => log.push('app'), true);
  registry.perform(E.LAYOUT);
  log.length = 0;
  registry.rearm('cyl.core.layoutBlock');
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['core']);
});

test('re-arm by event skips keyed callbacks', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('core'), true, 'cyl.core.layoutBlock');
  registry.addCallback(E.LAYOUT, () => log.push('app'), true);
  registry.perform(E.LAYOUT);
  log.length = 0;
  registry.rearm(E.LAYOUT);
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['app']);
});

test('cancel by key removes only that callback', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('core'), true, 'cyl.core.layoutBlock');
  registry.addCallback(E.LAYOUT, () => log.push('app'), true);
  assert.equal(registry.cancel('cyl.core.layoutBlock'), true);
  assert.equal(registry.cancel('cyl.core.layoutBlock'), false);
  registry.rearm(E.LAYOUT);
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['app']);
});

test('cancel a willDealloc callback by key returns true once', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.willDealloc(() => log.push('never'), 'k');
  assert.equal(registry.cancel('k'), true);
  assert.equal(registry.cancel('k'), false);
  registry.dealloc();
  assert.deepEqual(log, []);
});

test('add and cancel inside a callback', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  let laterId = 0;
  registry.addCallback(E.ABOUT_TO_APPEAR, () => {
    log.push('first');
    registry.cancel(laterId);
    registry.addCallback(E.PAGE_SHOW, () => log.push('added'));
  });
  laterId = registry.addCallback(E.ABOUT_TO_APPEAR, () => log.push('later'));
  registry.perform(E.ABOUT_TO_APPEAR);
  registry.perform(E.PAGE_SHOW);
  assert.deepEqual(log, ['first', 'added']);
});

test('dealloc shares identifiers, runs in order with info, keyed replacement', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  const a = registry.willDealloc((_o, id) => log.push('old:' + id));
  const b = registry.addCallback(E.ABOUT_TO_APPEAR, noop);
  const c = registry.willDealloc((_o, id, info) => log.push('new:' + id + ':' + info.isDealloc));
  registry.willDealloc(() => log.push('key1'), 'k');
  registry.willDealloc(() => log.push('key2'), 'k');
  assert.ok(a < b && b < c);
  registry.dealloc();
  assert.deepEqual(log, ['old:1', 'new:3:true', 'key2']);
});

test('dealloc runs once, a cancel during it has no effect, add after it returns 0', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  let second = 0;
  registry.willDealloc(() => {
    log.push('first');
    assert.equal(registry.cancel(second), false);
  });
  second = registry.willDealloc(() => log.push('second'));
  registry.dealloc();
  registry.dealloc();
  assert.deepEqual(log, ['first', 'second']);
  assert.equal(registry.willDealloc(() => log.push('late')), cylDeallocCallbackIllegalIdentifier);
  assert.equal(registry.addCallback(E.PAGE_SHOW, () => log.push('late')), cylDeallocCallbackIllegalIdentifier);
  registry.perform(E.PAGE_SHOW);
  assert.deepEqual(log, ['first', 'second']);
});

test('cancelAllWillDealloc keeps keyed callbacks', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.willDealloc(() => log.push('core'), 'cyl.core.kvo');
  registry.willDealloc(() => log.push('app'));
  registry.cancelAllWillDealloc();
  registry.dealloc();
  assert.deepEqual(log, ['core']);
});

test('app cancelAll keeps the core keyed callbacks', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.PAGE_SHOW, () => log.push('core'), false, 'cyl.core.start');
  registry.addCallback(E.PAGE_SHOW, () => log.push('app'));
  registry.cancelAll(E.PAGE_SHOW);
  registry.perform(E.PAGE_SHOW);
  assert.deepEqual(log, ['core']);
});

test('a listener removed by the dealloc callback, with or without ABOUT_TO_APPEAR', () => {
  for (const appeared of [true, false]) {
    const listeners = new Set();
    const registry = new CYLLifecycleCallbacks({});
    const listener = {};
    listeners.add(listener);
    registry.willDealloc(() => listeners.delete(listener));
    if (appeared) registry.perform(E.ABOUT_TO_APPEAR);
    assert.equal(listeners.size, 1);
    registry.perform(E.ABOUT_TO_DISAPPEAR);
    registry.dealloc(E.ABOUT_TO_DISAPPEAR);
    assert.equal(listeners.size, 0, 'appeared=' + appeared);
  }
});

test('perform fills in the event and keeps extras; dealloc info has the event given', () => {
  const registry = new CYLLifecycleCallbacks({});
  const seen = [];
  registry.addCallback(E.PAGE_HIDE, (_o, _i, info) => seen.push(cylLifecycleEventName(info.event) + ':' + info.isDealloc + ':' + info.extras.get('x')));
  registry.willDealloc((_o, _i, info) => seen.push('dealloc:' + cylLifecycleEventName(info.event) + ':' + info.isDealloc));
  registry.perform(E.PAGE_HIDE, new CYLLifecycleInfo(0, true, new Map([['x', 1]])));
  registry.dealloc(E.ABOUT_TO_DISAPPEAR);
  assert.deepEqual(seen, ['PAGE_HIDE:false:1', 'dealloc:ABOUT_TO_DISAPPEAR:true']);
});

test('every lifecycle event is dispatched in the order the owner performs them, then dealloc after ABOUT_TO_DISAPPEAR', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  for (const event of [E.ABOUT_TO_APPEAR, E.PAGE_SHOW, E.PAGE_HIDE, E.BACK_PRESS, E.ABOUT_TO_DISAPPEAR, E.LAYOUT]) {
    registry.addCallback(event, (_o, _i, info) => log.push(cylLifecycleEventName(info.event)));
  }
  registry.willDealloc((_o, _i, info) => log.push('dealloc:' + cylLifecycleEventName(info.event) + ':' + info.isDealloc));
  for (const event of [E.ABOUT_TO_APPEAR, E.PAGE_SHOW, E.PAGE_HIDE, E.BACK_PRESS, E.ABOUT_TO_DISAPPEAR]) registry.perform(event);
  registry.dealloc(E.ABOUT_TO_DISAPPEAR);
  assert.deepEqual(log, ['ABOUT_TO_APPEAR', 'PAGE_SHOW', 'PAGE_HIDE', 'BACK_PRESS', 'ABOUT_TO_DISAPPEAR', 'dealloc:ABOUT_TO_DISAPPEAR:true']);
});

test('rearm by event always answers true; rearm of an unknown key answers false', () => {
  const registry = new CYLLifecycleCallbacks({});
  assert.equal(registry.rearm(E.LAYOUT), true);
  assert.equal(registry.rearm('nope'), false);
});
