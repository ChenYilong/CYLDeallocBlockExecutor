const assert = require('node:assert/strict');
const { beforeEach, test } = require('node:test');
const { LifecycleRegistry } = require('../registry.js');

const e = 'viewDidLayoutSubviews'         ;
let owner        ;
let r                   ;
let log          ;

beforeEach(() => {
  owner = {};
  r = LifecycleRegistry.of(owner);
  log = [];
});

function fire(t                  = 'end') {
  r.setManualLifecycleDispatch(true, [e]);
  r.invokeLifecycleCallbacks(e, t);
}

test('one registry per owner',() => {
  assert.equal(LifecycleRegistry.of(owner), r);
});

test('order by identifier, owner and identifier in every block (typed owner)',() => {
  const a = r.addLifecycleCallback        (e, (o, id) => {
    assert.equal(o, owner);
    log.push(`a${id}`);
  }, { timing: 'end' });
  const b = r.addLifecycleCallback        (e, (_o, id) => log.push(`b${id}`), { timing: 'end' });
  assert.ok(b > a);
  fire();
  assert.deepEqual(log, [`a${a}`, `b${b}`]);
});

test('cancel one by identifier and by key; unknown identifier is false',() => {
  const a = r.addLifecycleCallback(e,() => log.push('a'), { timing: 'end' });
  r.addLifecycleCallback(e,() => log.push('b'), { timing: 'end', key: 'k' });
  r.addLifecycleCallback(e,() => log.push('c'), { timing: 'end' });
  assert.equal(r.cancelLifecycleCallback({ identifier: a }), true);
  assert.equal(r.cancelLifecycleCallback({ identifier: a }), false);
  assert.equal(r.cancelLifecycleCallback({ key: 'k' }), true);
  fire();
  assert.deepEqual(log, ['c']);
});

test('cancel all by event and timing',() => {
  r.addLifecycleCallback(e,() => log.push('end'), { timing: 'end' });
  r.addLifecycleCallback(e,() => log.push('after'));
  r.cancelAllLifecycleCallbacks(e, 'end');
  fire();
  fire('afterSuper');
  assert.deepEqual(log, ['after']);
});

test('invoke once, re-arm runs it again',() => {
  r.addLifecycleCallback(e,() => log.push('once'), { timing: 'end', invokeOnce: true });
  fire();
  fire();
  assert.deepEqual(log, ['once']);
  r.rearmLifecycleCallbacks(e);
  fire();
  assert.deepEqual(log, ['once', 'once']);
});

test('replace by key starts unfired and keeps one block',() => {
  const key = 'cyl.core.layoutBlock';
  r.addLifecycleCallback(e,() => log.push('old'), { timing: 'end', invokeOnce: true, key });
  fire();
  r.addLifecycleCallback(e,() => log.push('new'), { timing: 'end', invokeOnce: true, key });
  fire();
  fire();
  assert.deepEqual(log, ['old', 'new']);
  assert.equal(r.blockCount, 1);
});

test('isolation: cancel-all and re-arm by event skip keyed blocks',() => {
  r.addLifecycleCallback(e,() => log.push('core'), { timing: 'end', invokeOnce: true, key: 'cyl.core.x' });
  r.addLifecycleCallback(e,() => log.push('app'), { timing: 'end', invokeOnce: true });
  fire();
  r.rearmLifecycleCallbacks(e);
  fire();
  assert.deepEqual(log, ['core', 'app', 'app']);
  r.cancelAllLifecycleCallbacks(e);
  assert.equal(r.blockCount, 1);
  r.rearmLifecycleCallback('cyl.core.x');
  fire();
  assert.equal(log.at(-1), 'core');
});

test('add and cancel from inside a block; replacing a key inside a block skips the old one',() => {
  let second = 0;
  r.addLifecycleCallback(e,() => {
    log.push('first');
    r.cancelLifecycleCallback({ identifier: second });
    r.addLifecycleCallback(e,() => log.push('added'), { timing: 'end' });
  }, { timing: 'end' });
  second = r.addLifecycleCallback(e,() => log.push('second'), { timing: 'end' });
  fire();
  assert.deepEqual(log, ['first']);
  fire();
  assert.deepEqual(log, ['first', 'first', 'added']);
});

test('info carries event and timing',() => {
  r.addLifecycleCallback(e, (_o, _id, i) => log.push(`${i.event}/${i.timing}`), { timing: 'end' });
  fire();
  assert.deepEqual(log, ['viewDidLayoutSubviews/end']);
});

test('performLifecycle without a hook: all timings, once at the outermost',() => {
  for (const t of ['beforeSuper', 'afterSuper', 'end']         ) {
    r.addLifecycleCallback(e,() => log.push(t), { timing: t });
  }
  r.performLifecycle(e, {
    callSuper:() => {
      log.push('super');
      r.performLifecycle(e, { callSuper:() => log.push('inner super'), body:() => log.push('inner body') });
    },
    body:() => log.push('body'),
  });
  assert.deepEqual(log, ['beforeSuper', 'super', 'inner super', 'inner body', 'afterSuper', 'body', 'end']);
});

test('performLifecycle with a hook adds only end',() => {
  r.hookInstalled = true;
  for (const t of ['beforeSuper', 'afterSuper', 'end']         ) {
    r.addLifecycleCallback(e,() => log.push(t), { timing: t });
  }
  r.performLifecycle(e, { callSuper:() => log.push('super'), body:() => log.push('body') });
  assert.deepEqual(log, ['super', 'body', 'end']);
});

test('manual per timing: the hook skips only the declared timing',() => {
  r.hookInstalled = true;
  r.setManualLifecycleDispatch(true, [e], ['end']);
  assert.equal(r.isAutomatic(e, 'afterSuper'), true);
  assert.equal(r.isAutomatic(e, 'end'), false);
  r.addLifecycleCallback(e,() => log.push('end'), { timing: 'end' });
  r.performLifecycle(e, { callSuper:() => {}, body:() => {} });
  assert.deepEqual(log, []);
  r.invokeLifecycleCallbacks(e, 'end');
  assert.deepEqual(log, ['end']);
});

test('raw invoke needs the event declared manual',() => {
  assert.throws(() => r.invokeLifecycleCallbacks(e, 'end'), /manual/);
});

test('dealloc: order, once, shared identifiers, keyed replacement',() => {
  const a = r.addDeallocCallback((_o, id, i) => {
    assert.equal(i.isDealloc, true);
    log.push(`a${id}`);
  });
  const l = r.addLifecycleCallback(e,() => {}, { timing: 'end' });
  r.addDeallocCallback(() => log.push('old'), { key: 'k' });
  r.addDeallocCallback(() => log.push('new'), { key: 'k' });
  assert.equal(l, a + 1);
  r.runDealloc();
  r.runDealloc();
  assert.deepEqual(log, [`a${a}`, 'new']);
});

test('dealloc isolation: cancel-all keeps keyed, cancel by key removes it',() => {
  r.addDeallocCallback(() => log.push('app'));
  r.addDeallocCallback(() => log.push('core'), { key: 'cyl.core.kvo' });
  r.cancelAllDeallocCallbacks();
  r.runDealloc();
  assert.deepEqual(log, ['core']);
  log.length = 0;
  r.addDeallocCallback(() => log.push('core2'), { key: 'cyl.core.kvo' });
  assert.equal(r.cancelDeallocCallback({ key: 'cyl.core.kvo' }), true);
  r.runDealloc();
  assert.deepEqual(log, []);
});

test('replacing a key inside a block: the old block in the running snapshot is skipped',() => {
  r.addLifecycleCallback(e,() => {
    log.push('first');
    r.addLifecycleCallback(e,() => log.push('replacement'), { timing: 'end', key: 'k' });
  }, { timing: 'end' });
  r.addLifecycleCallback(e,() => log.push('old'), { timing: 'end', key: 'k' });
  fire();
  assert.deepEqual(log, ['first'], 'old was cancelled by the replacement before its turn');
  assert.equal(r.blockCount, 2, 'one block per key');
  r.cancelLifecycleCallback({ identifier: 1 });
  fire();
  assert.deepEqual(log, ['first', 'replacement']);
});

test('works without WeakRef (older Mini Program engines)', async () => {
  const saved = globalThis.WeakRef;
  globalThis.WeakRef = undefined;
  try {
    const o = {};
    const reg = new LifecycleRegistry(o);
    let hit = 0;
    reg.addLifecycleCallback('viewDidLoad', () => hit++);
    reg.fireAutomatic('viewDidLoad', 'afterSuper');
    assert.equal(hit, 1);
  } finally {
    globalThis.WeakRef = saved;
  }
});
