'use strict';
const assert = require('node:assert/strict');
const { beforeEach, test } = require('node:test');
const { withLifecycle, withComponentLifecycle, LifecycleRegistry } = require('../index');

// A fake `wx` and a fake page host: adapter tests, no WeChat devtools run.
class FakeWx {
  constructor() {
    this.handlers = { resize: [], theme: [], memory: [] };
    this.window = { windowWidth: 400, windowHeight: 800, screenWidth: 400, screenHeight: 800, safeArea: { top: 0, left: 0, right: 400, bottom: 800 } };
    this.theme = 'light';
    this.ticks = [];
  }
  onWindowResize(h) { this.handlers.resize.push(h); }
  offWindowResize(h) { this.handlers.resize.splice(this.handlers.resize.indexOf(h), 1); }
  onThemeChange(h) { this.handlers.theme.push(h); }
  offThemeChange(h) { this.handlers.theme.splice(this.handlers.theme.indexOf(h), 1); }
  onMemoryWarning(h) { this.handlers.memory.push(h); }
  offMemoryWarning(h) { this.handlers.memory.splice(this.handlers.memory.indexOf(h), 1); }
  getWindowInfo() { return this.window; }
  getAppBaseInfo() { return { theme: this.theme }; }
  nextTick(f) { this.ticks.push(f); }
  flush() { while (this.ticks.length) this.ticks.shift()(); }
}

let wx, log;
beforeEach(() => { wx = new FakeWx(); log = []; });

function watch(registry, ...events) {
  for (const ev of events) for (const t of ['beforeSuper', 'afterSuper', 'end']) {
    registry.addLifecycleCallback(ev, () => log.push(`${ev}/${t}`), { timing: t });
  }
}
const mkPage = (options) => {
  const w = withLifecycle(options, { wx });
  const page = {};
  for (const k of ['onLoad', 'onShow', 'onReady', 'onHide', 'onUnload', 'onResize']) page[k] = (...a) => w[k].apply(page, a);
  return page;
};

test('page: load fires move and load events; the page handler sits between afterSuper and end', () => {
  const page = mkPage({
    lifecycle: (registry) => watch(registry, 'viewDidLoad'),
    onLoad() { log.push('page onLoad'); },
  });
  page.onLoad();
  assert.deepEqual(log, ['viewDidLoad/beforeSuper', 'viewDidLoad/afterSuper', 'page onLoad', 'viewDidLoad/end']);
});

test('page: show fires will and isAppearing, ready fires did; later shows fire did on the next tick', () => {
  const page = mkPage({
    lifecycle: (registry) => watch(registry, 'viewWillAppear', 'viewIsAppearing', 'viewDidAppear'),
  });
  const names = () => log.filter((l) => l.endsWith('afterSuper')).map((l) => l.split('/')[0]);
  page.onLoad(); page.onShow();
  assert.deepEqual(names(), ['viewWillAppear', 'viewIsAppearing']);
  page.onReady();
  assert.deepEqual(names(), ['viewWillAppear', 'viewIsAppearing', 'viewDidAppear']);
  log.length = 0;
  page.onHide(); page.onShow();
  assert.deepEqual(names(), ['viewWillAppear', 'viewIsAppearing']);
  wx.flush();
  assert.deepEqual(names(), ['viewWillAppear', 'viewIsAppearing', 'viewDidAppear']);
});

test('page: hide fires will and did disappear back to back (no split)', () => {
  const page = mkPage({ lifecycle: (r) => watch(r, 'viewWillDisappear', 'viewDidDisappear') });
  page.onLoad(); page.onHide();
  assert.deepEqual(log.filter((l) => l.endsWith('afterSuper')), ['viewWillDisappear/afterSuper', 'viewDidDisappear/afterSuper']);
});

test('page: unload runs teardown blocks in order after the move events, sources removed', () => {
  const page = mkPage({ lifecycle: (r) => {
    watch(r, 'didMoveToParent');
    r.addDeallocCallback(() => log.push('a'));
    r.addDeallocCallback(() => log.push('b'));
    r.addLifecycleCallback('didReceiveMemoryWarning', () => {});
  } });
  page.onLoad();
  assert.equal(wx.handlers.memory.length, 1);
  log.length = 0;
  page.onUnload(); page.onUnload();
  assert.deepEqual(log.slice(-2), ['a', 'b']);
  assert.ok(log.includes('didMoveToParent/afterSuper'));
  assert.equal(wx.handlers.memory.length, 0);
});

test('move events carry parentAttached', () => {
  const seen = [];
  const page = mkPage({ lifecycle: (r) => r.addLifecycleCallback('willMoveToParent', (_o, _i, info) => seen.push(info.parentAttached)) });
  page.onLoad(); page.onUnload();
  assert.deepEqual(seen, [true, false]);
});

test('resize: viewWillTransition with the new size; unchanged size does not fire', () => {
  const sizes = [];
  const page = mkPage({ lifecycle: (r) => r.addLifecycleCallback('viewWillTransition', (_o, _i, info) => sizes.push(info.size)) });
  page.onLoad();
  wx.handlers.resize.forEach((h) => h({ size: { windowWidth: 400, windowHeight: 800 } }));
  assert.deepEqual(sizes, []);
  wx.handlers.resize.forEach((h) => h({ size: { windowWidth: 800, windowHeight: 400 } }));
  assert.deepEqual(sizes, [{ width: 800, height: 400 }]);
  page.onResize({ size: { windowWidth: 300, windowHeight: 600 } });
  assert.equal(sizes.length, 2, 'the page-level onResize feeds the same event');
});

test('theme change with the previous theme', () => {
  const prev = [];
  const page = mkPage({ lifecycle: (r) => r.addLifecycleCallback('traitCollectionDidChange', (_o, _i, info) => prev.push(info.previousTheme)) });
  page.onLoad();
  wx.handlers.theme.forEach((h) => h({ theme: 'dark' }));
  wx.handlers.theme.forEach((h) => h({ theme: 'light' }));
  assert.deepEqual(prev, ['light', 'dark']);
});

test('memory warning with the level', () => {
  const levels = [];
  const page = mkPage({ lifecycle: (r) => r.addLifecycleCallback('didReceiveMemoryWarning', (_o, _i, info) => levels.push(info.level)) });
  page.onLoad();
  wx.handlers.memory.forEach((h) => h({ level: 10 }));
  assert.deepEqual(levels, [10]);
});

test('safe area insets: sampled on show and resize, previous insets in info, unchanged does not fire', () => {
  const seen = [];
  const page = mkPage({ lifecycle: (r) => r.addLifecycleCallback('viewSafeAreaInsetsDidChange', (_o, _i, info) => seen.push(info.previousInsets)) });
  page.onLoad(); page.onShow();
  assert.deepEqual(seen, []);
  wx.window.safeArea = { top: 47, left: 0, right: 400, bottom: 766 };
  page.onShow();
  assert.deepEqual(seen, [{ top: 0, left: 0, bottom: 0, right: 0 }]);
  page.onShow();
  assert.equal(seen.length, 1);
});

test('sources are subscribed lazily on the first block', () => {
  const page = mkPage({});
  page.onLoad();
  assert.equal(wx.handlers.resize.length + wx.handlers.theme.length + wx.handlers.memory.length, 0);
  LifecycleRegistry.of(page).addLifecycleCallback('viewWillTransition', () => {});
  assert.equal(wx.handlers.resize.length, 1);
});

test('foreground and background fire the appear events again (differs from iOS)', () => {
  const page = mkPage({ lifecycle: (r) => watch(r, 'viewWillAppear') });
  page.onLoad(); page.onShow(); page.onHide(); page.onShow();
  assert.equal(log.filter((l) => l === 'viewWillAppear/afterSuper').length, 2);
});

test('component: attached, ready, detached and the page lifetimes drive the same events', () => {
  const w = withComponentLifecycle({
    lifecycle: (r) => { watch(r, 'viewDidLoad', 'viewWillAppear', 'viewDidDisappear'); r.addDeallocCallback(() => log.push('dealloc')); },
    lifetimes: { attached() { log.push('component attached'); } },
  }, { wx });
  const c = {};
  w.lifetimes.attached.call(c);
  w.pageLifetimes.show.call(c);
  w.pageLifetimes.hide.call(c);
  w.lifetimes.detached.call(c);
  assert.ok(log.includes('component attached'));
  for (const n of ['viewDidLoad/afterSuper', 'viewWillAppear/afterSuper', 'viewDidDisappear/afterSuper', 'dealloc']) assert.ok(log.includes(n), n);
  assert.equal(log[log.length - 1], 'dealloc');
});

test('end is automatic here because the wrapper knows the handler body', () => {
  const page = mkPage({ lifecycle: (r) => watch(r, 'viewWillAppear'), onShow() { log.push('body'); } });
  page.onLoad(); page.onShow();
  assert.deepEqual(log, ['viewWillAppear/beforeSuper', 'viewWillAppear/afterSuper', 'body', 'viewWillAppear/end']);
});

test('manual end beside automatic afterSuper through the wrapper', () => {
  const page = mkPage({ lifecycle: (r) => {
    r.setManualLifecycleDispatch(true, ['viewWillAppear'], ['end']);
    watch(r, 'viewWillAppear');
  } });
  page.onLoad(); page.onShow();
  assert.ok(!log.includes('viewWillAppear/end'));
  LifecycleRegistry.of(page).invokeLifecycleCallbacks('viewWillAppear', 'end');
  assert.ok(log.includes('viewWillAppear/end'));
});
