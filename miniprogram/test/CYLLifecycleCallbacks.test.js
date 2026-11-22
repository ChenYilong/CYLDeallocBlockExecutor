// [EN] Unit tests of CYLLifecycleCallbacks, the Mini Program port of the callback registry: the same cases as the Kotlin
//      CYLLifecycleCallbacksTest and the HarmonyOS tests (docs/Lifecycle-Callbacks.md maps each one to the iOS checks), plus the
//      Behavior factory with a mocked Behavior and Component. Run: cd miniprogram && npm test
// [CN] CYLLifecycleCallbacks（回调注册表的小程序移植）的单元测试：用例与 Kotlin 的 CYLLifecycleCallbacksTest 及鸿蒙测试相同
//      （docs/Lifecycle-Callbacks.md 逐项对照 iOS 检查），另有用模拟的 Behavior 与 Component 测试的 Behavior 工厂。运行：cd miniprogram && npm test
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  CYLLifecycleCallbacks, CYLLifecycleEvent, CYLLifecycleInfo, cylLifecycleEventName, cylDeallocCallbackIllegalIdentifier,
} = require('../cyl-dealloc-block-executor');

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
  const ids = [0, 1, 2].map((index) => registry.addCallback(E.SHOW, (received, id) => {
    typed = received === owner;
    log.push(index + ':' + id);
  }));
  registry.cancel(ids[1]);
  registry.perform(E.SHOW);
  assert.deepEqual(log, ['0:' + ids[0], '2:' + ids[2]]);
  assert.ok(typed);
});

test('cancelAll removes the unkeyed callbacks of the event', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.SHOW, () => log.push('show'));
  registry.addCallback(E.HIDE, () => log.push('hide'));
  registry.cancelAll(E.SHOW);
  registry.perform(E.SHOW);
  registry.perform(E.HIDE);
  assert.deepEqual(log, ['hide']);
});

test('invokeOnce runs once until rearmed by key', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('end1'), { invokeOnce: true, key: 'layoutBlock' });
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
  registry.addCallback(E.LAYOUT, () => log.push('end1'), { invokeOnce: true, key: 'layoutBlock' });
  registry.perform(E.LAYOUT);
  log.length = 0;
  registry.addCallback(E.LAYOUT, () => log.push('end2'), { invokeOnce: true, key: 'layoutBlock' });
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['end2']);
});

test('the core re-arms by key, the app run-once block stays fired', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('core'), { invokeOnce: true, key: 'cyl.core.layoutBlock' });
  registry.addCallback(E.LAYOUT, () => log.push('app'), { invokeOnce: true });
  registry.perform(E.LAYOUT);
  log.length = 0;
  registry.rearm('cyl.core.layoutBlock');
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['core']);
});

test('re-arm by event skips keyed callbacks', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('core'), { invokeOnce: true, key: 'cyl.core.layoutBlock' });
  registry.addCallback(E.LAYOUT, () => log.push('app'), { invokeOnce: true });
  registry.perform(E.LAYOUT);
  log.length = 0;
  registry.rearm(E.LAYOUT);
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['app']);
});

test('cancel by key removes only that callback', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.LAYOUT, () => log.push('core'), { invokeOnce: true, key: 'cyl.core.layoutBlock' });
  registry.addCallback(E.LAYOUT, () => log.push('app'), { invokeOnce: true });
  assert.equal(registry.cancel('cyl.core.layoutBlock'), true);
  assert.equal(registry.cancel('cyl.core.layoutBlock'), false);
  registry.rearm(E.LAYOUT);
  registry.perform(E.LAYOUT);
  assert.deepEqual(log, ['app']);
});

test('cancel a willDealloc callback by key returns true once', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.willDealloc(() => log.push('never'), { key: 'k' });
  assert.equal(registry.cancel('k'), true);
  assert.equal(registry.cancel('k'), false);
  registry.dealloc();
  assert.deepEqual(log, []);
});

test('add and cancel inside a callback', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  let laterId = 0;
  registry.addCallback(E.ATTACHED, () => {
    log.push('first');
    registry.cancel(laterId);
    registry.addCallback(E.SHOW, () => log.push('added'));
  });
  laterId = registry.addCallback(E.ATTACHED, () => log.push('later'));
  registry.perform(E.ATTACHED);
  registry.perform(E.SHOW);
  assert.deepEqual(log, ['first', 'added']);
});

test('dealloc shares identifiers, runs in order with info, keyed replacement', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  const a = registry.willDealloc((_o, id) => log.push('old:' + id));
  const b = registry.addCallback(E.ATTACHED, noop);
  const c = registry.willDealloc((_o, id, info) => log.push('new:' + id + ':' + info.isDealloc));
  registry.willDealloc(() => log.push('key1'), { key: 'k' });
  registry.willDealloc(() => log.push('key2'), { key: 'k' });
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
  assert.equal(registry.addCallback(E.SHOW, () => log.push('late')), cylDeallocCallbackIllegalIdentifier);
  registry.perform(E.SHOW);
  assert.deepEqual(log, ['first', 'second']);
});

test('cancelAllWillDealloc keeps keyed callbacks', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.willDealloc(() => log.push('core'), { key: 'cyl.core.kvo' });
  registry.willDealloc(() => log.push('app'));
  registry.cancelAllWillDealloc();
  registry.dealloc();
  assert.deepEqual(log, ['core']);
});

test('app cancelAll keeps the core keyed callbacks', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  registry.addCallback(E.SHOW, () => log.push('core'), { key: 'cyl.core.start' });
  registry.addCallback(E.SHOW, () => log.push('app'));
  registry.cancelAll(E.SHOW);
  registry.perform(E.SHOW);
  assert.deepEqual(log, ['core']);
});

test('a listener removed by the dealloc callback, with or without ATTACHED', () => {
  for (const appeared of [true, false]) {
    const listeners = new Set();
    const registry = new CYLLifecycleCallbacks({});
    const listener = {};
    listeners.add(listener);
    registry.willDealloc(() => listeners.delete(listener));
    if (appeared) registry.perform(E.ATTACHED);
    assert.equal(listeners.size, 1);
    registry.perform(E.DETACHED);
    registry.dealloc(E.DETACHED);
    assert.equal(listeners.size, 0, 'appeared=' + appeared);
  }
});

test('perform fills in the event and keeps extras; dealloc info has the event given', () => {
  const registry = new CYLLifecycleCallbacks({});
  const seen = [];
  registry.addCallback(E.HIDE, (_o, _i, info) => seen.push(cylLifecycleEventName(info.event) + ':' + info.isDealloc + ':' + info.extras.get('x')));
  registry.willDealloc((_o, _i, info) => seen.push('dealloc:' + cylLifecycleEventName(info.event) + ':' + info.isDealloc));
  registry.perform(E.HIDE, new CYLLifecycleInfo(0, true, new Map([['x', 1]])));
  registry.dealloc(E.DETACHED);
  assert.deepEqual(seen, ['HIDE:false:1', 'dealloc:DETACHED:true']);
});

test('every lifecycle event is dispatched in the order the owner performs them, then dealloc after DETACHED', () => {
  const registry = new CYLLifecycleCallbacks({});
  const log = [];
  for (const event of [E.ATTACHED, E.SHOW, E.HIDE, E.READY, E.DETACHED, E.LAYOUT]) {
    registry.addCallback(event, (_o, _i, info) => log.push(cylLifecycleEventName(info.event)));
  }
  registry.willDealloc((_o, _i, info) => log.push('dealloc:' + cylLifecycleEventName(info.event) + ':' + info.isDealloc));
  for (const event of [E.ATTACHED, E.SHOW, E.HIDE, E.READY, E.DETACHED]) registry.perform(event);
  registry.dealloc(E.DETACHED);
  assert.deepEqual(log, ['ATTACHED', 'SHOW', 'HIDE', 'READY', 'DETACHED', 'dealloc:DETACHED:true']);
});

test('rearm by event always answers true; rearm of an unknown key answers false', () => {
  const registry = new CYLLifecycleCallbacks({});
  assert.equal(registry.rearm(E.LAYOUT), true);
  assert.equal(registry.rearm('nope'), false);
});

test('cylLifecycleBehavior: a registry per component, lifetimes and pageLifetimes dispatched, dealloc after detached', () => {
  let definition;
  const behavior = require('../cyl-dealloc-block-executor').cylLifecycleBehavior((d) => { definition = d; return d; });
  assert.equal(behavior, definition);
  const component = {};
  const log = [];
  definition.lifetimes.created.call(component);
  const registry = component.cylLifecycle;
  assert.ok(registry instanceof CYLLifecycleCallbacks);
  for (const event of [E.CREATED, E.ATTACHED, E.READY, E.MOVED, E.DETACHED, E.SHOW, E.HIDE, E.RESIZE]) {
    registry.addCallback(event, (owner, _id, info) => log.push(cylLifecycleEventName(info.event) + (owner === component ? '' : '!')));
  }
  registry.addCallback(E.RESIZE, (_o, _i, info) => log.push('size:' + info.extras.get('size').windowWidth));
  registry.willDealloc((_o, _i, info) => log.push('dealloc:' + cylLifecycleEventName(info.event) + ':' + info.isDealloc));
  definition.lifetimes.attached.call(component);
  definition.pageLifetimes.show.call(component);
  definition.lifetimes.ready.call(component);
  definition.lifetimes.moved.call(component);
  definition.pageLifetimes.resize.call(component, { windowWidth: 375 });
  definition.pageLifetimes.hide.call(component);
  definition.lifetimes.detached.call(component);
  assert.deepEqual(log, ['ATTACHED', 'SHOW', 'READY', 'MOVED', 'RESIZE', 'size:375', 'HIDE', 'DETACHED', 'dealloc:DETACHED:true']);
  assert.equal(registry.willDealloc(() => {}), cylDeallocCallbackIllegalIdentifier);
});

test('cylLifecycleBehavior: two components do not share a registry, the property name is configurable, detached deallocs only its own', () => {
  let definition;
  require('../cyl-dealloc-block-executor').cylLifecycleBehavior((d) => { definition = d; return d; }, 'registry');
  const a = {};
  const b = {};
  definition.lifetimes.created.call(a);
  definition.lifetimes.created.call(b);
  assert.notEqual(a.registry, b.registry);
  assert.equal(a.cylLifecycle, undefined);
  definition.lifetimes.detached.call(a);
  assert.equal(a.registry.deallocated, true);
  assert.equal(b.registry.deallocated, false);
});
