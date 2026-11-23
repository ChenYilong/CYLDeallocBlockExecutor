const assert = require('node:assert/strict');
const { beforeEach, test } = require('node:test');
const { LifecycleController, LifecycleRegistry, withLifecycle } = require('../index.js');

let owner, c, log;
beforeEach(() => {
  owner = {};
  c = new LifecycleController(owner);
  log = [];
});
const on = (event, timing = 'afterSuper') =>
  c.registry.addLifecycleCallback(event, (_o, _id, info) => log.push(`${event}/${info.timing}`), { timing });

test('onLoad: move and load events, once', () => {
  on('willMoveToParent');
  on('viewDidLoad', 'beforeSuper');
  on('didMoveToParent');
  c.onLoad();
  c.onLoad();
  assert.deepEqual(log, ['willMoveToParent/afterSuper', 'viewDidLoad/beforeSuper', 'didMoveToParent/afterSuper']);
});

test('first show: viewDidAppear waits for onReady', () => {
  on('viewWillAppear');
  on('viewIsAppearing');
  on('viewDidAppear');
  c.onShow();
  assert.deepEqual(log, ['viewWillAppear/afterSuper', 'viewIsAppearing/afterSuper']);
  c.onReady();
  c.onReady();
  assert.equal(log.at(-1), 'viewDidAppear/afterSuper');
  assert.equal(log.length, 3);
});

test('later shows fire did appear straight away; hide fires will and did disappear', () => {
  on('viewDidAppear');
  on('viewWillDisappear');
  on('viewDidDisappear');
  c.onShow();
  c.onReady();
  c.onHide();
  c.onHide();
  c.onShow();
  assert.deepEqual(log.map((l) => l.split('/')[0]), ['viewDidAppear', 'viewWillDisappear', 'viewDidDisappear', 'viewDidAppear']);
});

test('onResize carries the window size', () => {
  c.registry.addLifecycleCallback('viewWillTransition', (_o, _i, info) => log.push(`${info.size.width}x${info.size.height}`));
  c.onResize({ windowWidth: 375, windowHeight: 667 });
  c.onResize({ size: undefined, width: 667, height: 375 });
  assert.deepEqual(log, ['375x667', '667x375']);
});

test('theme change carries the previous theme; the first report is only recorded', () => {
  c.registry.addLifecycleCallback('traitCollectionDidChange', (_o, _i, info) => log.push(info.previousColorScheme));
  c.themeChanged('light');
  c.themeChanged('light');
  c.themeChanged('dark');
  assert.deepEqual(log, ['light']);
});

test('memory warning', () => {
  on('didReceiveMemoryWarning');
  c.memoryWarning();
  assert.equal(log.length, 1);
});

test('onUnload: hides, moves, then runs teardown blocks in order, once', () => {
  on('viewDidDisappear');
  on('didMoveToParent');
  c.registry.addDeallocCallback((_o, _id, info) => log.push(`dealloc ${info.isDealloc}`));
  c.onShow();
  c.onUnload();
  c.onUnload();
  assert.deepEqual(log, ['viewDidDisappear/afterSuper', 'didMoveToParent/afterSuper', 'dealloc true']);
  c.onShow();
  assert.equal(log.length, 3);
});

test('withLifecycle wraps the Page options and still calls the originals', () => {
  const calls = [];
  const options = withLifecycle({
    onLoad() { calls.push('load'); },
    onShow() { calls.push('show'); },
    onUnload() { calls.push('unload'); },
    data: { a: 1 },
  });
  const page = Object.assign({}, options);
  page.onLoad();
  page.onShow();
  page.onUnload();
  assert.deepEqual(calls, ['load', 'show', 'unload']);
  assert.deepEqual(page.data, { a: 1 });
});

test('withLifecycle: the load events fire before the original onLoad, so a block added inside it only sees later events', () => {
  const calls = [];
  const options = withLifecycle({
    onLoad() {
      calls.push('load');
      this.cylController.registry.addLifecycleCallback('didMoveToParent', () => calls.push('moved'));
    },
  });
  const page = Object.assign({}, options);
  page.onLoad();
  assert.deepEqual(calls, ['load']);
  page.onShow();
  page.onShow();
  page.onHide();
  assert.deepEqual(calls, ['load']);
});

test('the registry is shared with the owner', () => {
  assert.equal(LifecycleRegistry.of(owner), c.registry);
});

test('isDetached is true after onUnload', () => {
  assert.equal(c.isDetached, false);
  c.onUnload();
  assert.equal(c.isDetached, true);
});

test('window moves fire at onLoad and onUnload with the window', () => {
  const seen = []
  c.registry.addLifecycleCallback('willMoveToWindow', (_o, _i, info) => seen.push(`will ${info.window === null ? 'null' : 'window'}`))
  c.registry.addLifecycleCallback('didMoveToWindow', (_o, _i, info) => seen.push(`did ${info.window === null ? 'null' : 'window'}`))
  c.onLoad()
  c.onUnload()
  assert.deepEqual(seen, ['will window', 'did window', 'will null', 'did null'])
})

test('screen: onShow / onReady / onHide and screenVisible report transitions only', () => {
  on('didEnterScreen')
  on('didLeaveScreen')
  c.onShow()
  c.onReady()
  c.screenVisible(true)
  c.screenVisible(false)
  c.screenVisible(false)
  assert.deepEqual(log, ['didEnterScreen/afterSuper', 'didLeaveScreen/afterSuper'])
})

test('onPageScroll: the first event begins, a quiet period ends (debounced end)', async () => {
  c.scrollEndDelay = 10
  for (const e of ['scrollWillBeginDragging', 'scrollDidEndDragging', 'scrollDidEndScrolling']) {
    c.registry.addLifecycleCallback(e, (_o, _i, info) => log.push(`${e}${info.willDecelerate === undefined ? '' : ' ' + info.willDecelerate}`))
  }
  c.onPageScroll({ scrollTop: 1 })
  c.onPageScroll({ scrollTop: 5 })
  assert.deepEqual(log, ['scrollWillBeginDragging'])
  await new Promise((resolve) => setTimeout(resolve, 40))
  assert.deepEqual(log, ['scrollWillBeginDragging', 'scrollDidEndDragging false', 'scrollDidEndScrolling'])
  c.onPageScroll({ scrollTop: 9 })
  c.onUnload()
  await new Promise((resolve) => setTimeout(resolve, 40))
  assert.equal(log.length, 4, 'a detached page ends nothing later')
})
