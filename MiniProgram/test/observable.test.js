const assert = require('node:assert/strict');
const { beforeEach, test } = require('node:test');
const { LifecycleCenter, LifecycleRegistry } = require('../index.js');

let owner        ;
let r                   ;
let log          ;

beforeEach(() => {
  LifecycleCenter.reset();
  owner = {};
  r = LifecycleRegistry.of(owner);
  r.hookInstalled = true;
  log = [];
});

test('custom events: order by identifier, owner, userInfo and the event name in info', () => {
  const a = r.addCustomCallback('cyl.badge.didShow', (o, id, info) => {
    assert.equal(o, owner);
    log.push(`a${id} ${info.customEvent} ${info.userInfo?.value}`);
  });
  const b = r.addCustomCallback('cyl.badge.didShow', (_o, id) => log.push(`b${id}`));
  r.postLifecycleEvent('cyl.badge.didShow', { value: '3' });
  assert.deepEqual(log, [`a${a} cyl.badge.didShow 3`, `b${b}`]);
});

test('custom events: another name does not fire, invoke once, replace by key, cancel by identifier and by key', () => {
  r.addCustomCallback('x', () => log.push('x'), { invokeOnce: true });
  r.addCustomCallback('y', () => log.push('y1'), { key: 'k' });
  r.addCustomCallback('y', () => log.push('y2'), { key: 'k' });
  const id = r.addCustomCallback('y', () => log.push('y3'));
  r.postLifecycleEvent('x');
  r.postLifecycleEvent('x');
  r.postLifecycleEvent('y');
  assert.deepEqual(log, ['x', 'y2', 'y3']);
  log.length = 0;
  assert.equal(r.cancelLifecycleCallback({ identifier: id }), true);
  assert.equal(r.cancelLifecycleCallback({ key: 'k' }), true);
  r.postLifecycleEvent('y');
  assert.deepEqual(log, []);
});

test('custom events share one identifier sequence with lifecycle and dealloc blocks, and rearm by key works', () => {
  const a = r.addLifecycleCallback('viewDidLoad', () => {});
  const b = r.addCustomCallback('c', () => log.push('c'), { invokeOnce: true, key: 'once' });
  const c = r.addDeallocCallback(() => {});
  assert.ok(a < b && b < c);
  r.postLifecycleEvent('c');
  r.postLifecycleEvent('c');
  r.rearmLifecycleCallback('once');
  r.postLifecycleEvent('c');
  assert.deepEqual(log, ['c', 'c']);
});

test('a custom block added inside a custom block does not run in the running post', () => {
  r.addCustomCallback('c', () => {
    log.push('first');
    r.addCustomCallback('c', () => log.push('late'));
  });
  r.postLifecycleEvent('c');
  assert.deepEqual(log, ['first']);
});

test('global observers: run after the owner blocks, in identifier order, with the owner and the info', () => {
  r.addLifecycleCallback('viewDidAppear', () => log.push('own'));
  LifecycleCenter.addCallback('viewDidAppear', (o, id, info) => log.push(`g1 ${o === owner} ${info.event}`));
  LifecycleCenter.addCallback('viewDidAppear', () => log.push('g2'));
  r.fireAutomatic('viewDidAppear', 'afterSuper');
  assert.deepEqual(log, ['own', 'g1 true viewDidAppear', 'g2']);
});

test('global observers: a timing, an owner type, a key, cancel; never on teardown', () => {
  class A {}
  class B {}
  const a = new A();
  const ra = LifecycleRegistry.of(a);
  ra.hookInstalled = true;
  LifecycleCenter.addCallback('viewDidLoad', () => log.push('only A'), { ownerType: A });
  LifecycleCenter.addCallback('viewDidLoad', () => log.push('before'), { timing: 'beforeSuper', key: 'k' });
  LifecycleCenter.addCallback('viewDidLoad', () => log.push('replaced'), { timing: 'beforeSuper', key: 'k' });
  ra.fireAutomatic('viewDidLoad', 'beforeSuper');
  ra.fireAutomatic('viewDidLoad', 'afterSuper');
  LifecycleRegistry.of(new B()).fireAutomatic('viewDidLoad', 'afterSuper');
  assert.deepEqual(log, ['replaced', 'only A']);
  const id = LifecycleCenter.addCallback('viewDidLoad', () => log.push('gone'));
  assert.equal(LifecycleCenter.cancelCallback({ identifier: id }), true);
  assert.equal(LifecycleCenter.cancelCallback({ key: 'k' }), true);
  assert.equal(LifecycleCenter.cancelCallback({ key: 'k' }), false);
  log.length = 0;
  ra.addDeallocCallback(() => log.push('own dealloc'));
  LifecycleCenter.addCallback('viewDidLoad', () => log.push('global at dealloc'));
  ra.runDealloc();
  assert.deepEqual(log, ['own dealloc']);
});

test('global observers see custom events too', () => {
  LifecycleCenter.addCustomCallback('cyl.badge.didShow', (o, _id, info) => log.push(`${o === owner} ${info.userInfo?.value}`));
  r.postLifecycleEvent('cyl.badge.didShow', { value: '9' });
  assert.deepEqual(log, ['true 9']);
});

test('isUserScrolling: true between scrollWillBeginDragging and scrollDidEndScrolling of the source', () => {
  assert.equal(LifecycleCenter.isUserScrolling, false);
  r.fireAutomatic('scrollWillBeginDragging', 'afterSuper');
  assert.equal(LifecycleCenter.isUserScrolling, true);
  r.fireAutomatic('scrollDidEndDragging', 'afterSuper', { willDecelerate: true });
  assert.equal(LifecycleCenter.isUserScrolling, true, 'still decelerating');
  r.fireAutomatic('scrollDidEndScrolling', 'afterSuper');
  assert.equal(LifecycleCenter.isUserScrolling, false);
});

test('pause all animations while scrolling, resume after: the owner scenario', () => {
  const paused = new Set        ();
  const animations = ['icon', 'badge'];
  LifecycleCenter.addCallback('scrollWillBeginDragging', () => animations.forEach((a) => paused.add(a)));
  LifecycleCenter.addCallback('scrollDidEndScrolling', () => paused.clear());
  r.fireAutomatic('scrollWillBeginDragging', 'afterSuper');
  assert.deepEqual([...paused], animations);
  r.fireAutomatic('scrollDidEndScrolling', 'afterSuper');
  assert.equal(paused.size, 0);
});

test('forwarding: the target receives the forwarded events, a subset only those, replaced by a second forward', () => {
  const item = {};
  const ri = LifecycleRegistry.of(item);
  ri.hookInstalled = true;
  ri.addLifecycleCallback('didEnterScreen', () => log.push('item enter'));
  ri.addLifecycleCallback('didLeaveScreen', () => log.push('item leave'));
  ri.addCustomCallback('cyl.badge.didShow', () => log.push('item badge'));
  r.forwardLifecycleEvents(ri, ['didEnterScreen']);
  r.fireAutomatic('didEnterScreen', 'afterSuper');
  r.fireAutomatic('didLeaveScreen', 'afterSuper');
  assert.deepEqual(log, ['item enter']);
  log.length = 0;
  r.forwardLifecycleEvents(ri);
  r.fireAutomatic('didLeaveScreen', 'afterSuper');
  r.postLifecycleEvent('cyl.badge.didShow');
  assert.deepEqual(log, ['item leave', 'item badge']);
  log.length = 0;
  r.fireAutomatic('didEnterScreen', 'afterSuper');
  assert.deepEqual(log, ['item enter'], 'one forward per target: no double delivery');
});

test('debug log: off by default, lazy; on, it names the owner, event, timing and the number of blocks', () => {
  const { LifecycleLog } = require('../index.js');
  const lines           = [];
  LifecycleLog.sink = (m) => lines.push(m);
  r.addLifecycleCallback('viewDidAppear', () => {});
  r.fireAutomatic('viewDidAppear', 'afterSuper');
  assert.deepEqual(lines, [], 'disabled: nothing is built or printed');
  LifecycleLog.enabled = true;
  try {
    const named = { name: 'tab-1' };
    const rn = LifecycleRegistry.of(named);
    rn.hookInstalled = true;
    rn.addLifecycleCallback('viewDidAppear', () => {});
    rn.fireAutomatic('viewDidAppear', 'afterSuper');
    rn.addCustomCallback('cyl.animation.didPause', () => {});
    rn.postLifecycleEvent('cyl.animation.didPause');
    rn.addDeallocCallback(() => {});
    rn.runDealloc();
    assert.deepEqual(lines, [
      '[CYLLifecycle] Object(tab-1) viewDidAppear/afterSuper: 1 block(s)',
      '[CYLLifecycle] Object(tab-1) posts cyl.animation.didPause: 1 block(s)',
      '[CYLLifecycle] teardown Object(tab-1): 1 block(s)',
      '[CYLLifecycle] dealloc Object(tab-1)',
    ]);
  } finally {
    LifecycleLog.enabled = false;
    LifecycleLog.sink = (m) => console.log(m);
  }
});

test('a dealloc observer learns when any owner is torn down, with a description and never the owner', () => {
  const seen           = [];
  const id = LifecycleCenter.addDeallocObserver((description, info) => seen.push(`${description} ${info.isDealloc}`), { key: 'debug' });
  const named = { id: 7 };
  const rn = LifecycleRegistry.of(named);
  rn.runDealloc();
  assert.deepEqual(seen, ['Object(7) true']);
  assert.equal(LifecycleCenter.cancelDeallocObserver({ identifier: id }), true);
  rn.runDealloc();
  assert.equal(seen.length, 1);
});

test('the animation and badge event names are the documented ones', () => {
  const { AnimationEvents, BadgeEvents } = require('../index.js');
  assert.deepEqual(Object.values(AnimationEvents), ['cyl.animation.didStart', 'cyl.animation.didPause', 'cyl.animation.didResume', 'cyl.animation.didStop']);
  assert.equal(BadgeEvents.didShow, 'cyl.badge.didShow');
  assert.equal(BadgeEvents.animationDidStop, 'cyl.badge.animationDidStop');
});
