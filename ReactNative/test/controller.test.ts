import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';
import { LifecycleController, mountLifecycle } from '../src/index.ts';
import type { Insets, LifecycleEvent, PlatformSources } from '../src/index.ts';

type Fn = (...a: any[]) => void;

// Fake platform sources: adapter tests, no device run.
class Fakes {
  nav = new Map<string, Fn[]>();
  dim: Fn[] = [];
  app: Fn[] = [];
  mem: Fn[] = [];
  insets: Fn[] = [];
  removed = 0;
  size = { width: 400, height: 800, fontScale: 1 };
  scheme: string | null = 'light';
  inset: Insets = { top: 0, left: 0, bottom: 0, right: 0 };

  sources(platform = 'ios'): PlatformSources {
    const track = (list: Fn[], l: Fn) => {
      list.push(l);
      return { remove: () => { this.removed++; list.splice(list.indexOf(l), 1); } };
    };
    return {
      platform,
      navigation: {
        addListener: (type, l) => {
          const list = this.nav.get(type) ?? [];
          this.nav.set(type, list);
          return track(list, l);
        },
      },
      dimensions: { get: () => this.size, addEventListener: (_t, l) => track(this.dim, l) },
      appearance: { getColorScheme: () => this.scheme, addChangeListener: (l) => track(this.app, l) },
      appState: { addEventListener: (_t, l) => track(this.mem, l) },
      safeAreaInsets: { get: () => this.inset, subscribe: (l) => track(this.insets, l) },
    };
  }
  emit(type: string, e?: unknown) { this.nav.get(type)?.slice().forEach((l) => l(e)); }
}

let owner: object;
let f: Fakes;
let log: string[];

function make(platform = 'ios', events: LifecycleEvent[] = [], navigation: 'stack' | 'immediate' = 'stack') {
  const c = new LifecycleController(owner, f.sources(platform), { navigation });
  for (const ev of events) {
    for (const t of ['beforeSuper', 'afterSuper'] as const) {
      c.registry.addLifecycleCallback(ev, (_o, _id, i) => log.push(`${ev}/${t}`), { timing: t });
    }
  }
  return c;
}

beforeEach(() => { owner = {}; f = new Fakes(); log = []; });

test('attach fires move and load events with timings, detach fires move with parentAttached false', () => {
  const attached: Array<boolean | undefined> = [];
  const c = make('ios', ['willMoveToParent', 'viewDidLoad', 'didMoveToParent']);
  c.registry.addLifecycleCallback('willMoveToParent', (_o, _i, info) => attached.push(info.parentAttached));
  c.attach();
  assert.deepEqual(log, [
    'willMoveToParent/beforeSuper', 'willMoveToParent/afterSuper',
    'viewDidLoad/beforeSuper', 'viewDidLoad/afterSuper',
    'didMoveToParent/beforeSuper', 'didMoveToParent/afterSuper',
  ]);
  c.detach();
  assert.deepEqual(attached, [true, false]);
});

test('appear and disappear: will / did split from transitions, focus feeds viewIsAppearing', () => {
  const c = make('ios', ['viewWillAppear', 'viewIsAppearing', 'viewDidAppear', 'viewWillDisappear', 'viewDidDisappear']);
  c.attach();
  f.emit('transitionStart', { data: { closing: false } });
  assert.deepEqual(log.filter((l) => l.endsWith('afterSuper')), ['viewWillAppear/afterSuper']);
  f.emit('focus');
  f.emit('transitionEnd', { data: { closing: false } });
  assert.deepEqual(log.filter((l) => l.endsWith('afterSuper')), ['viewWillAppear/afterSuper', 'viewIsAppearing/afterSuper', 'viewDidAppear/afterSuper']);
  log.length = 0;
  f.emit('transitionStart', { data: { closing: true } });
  assert.deepEqual(log.filter((l) => l.endsWith('afterSuper')), ['viewWillDisappear/afterSuper']);
  f.emit('transitionEnd', { data: { closing: true } });
  assert.ok(log.includes('viewDidDisappear/afterSuper'));
});

test('app foreground / background never fires appear events', () => {
  const c = make('ios', ['viewWillAppear', 'viewDidAppear']);
  c.attach();
  // AppState "change" is not subscribed at all: nothing to emit, nothing fired.
  assert.deepEqual(log, []);
  assert.equal(f.mem.length + f.dim.length, 0);
});

test('a pending did event is flushed when the owner is detached', () => {
  const c = make('ios', ['viewDidAppear']);
  c.attach();
  f.emit('transitionStart', { data: { closing: false } });
  c.detach();
  assert.ok(log.includes('viewDidAppear/afterSuper'));
});

test('viewDidLayoutSubviews from onLayout, invoke once and re-arm', () => {
  const c = make();
  c.attach();
  c.registry.addLifecycleCallback('viewDidLayoutSubviews', () => log.push('layout'), { invokeOnce: true });
  c.onLayout({});
  c.onLayout({});
  assert.deepEqual(log, ['layout']);
  c.registry.rearmLifecycleCallbacks('viewDidLayoutSubviews');
  c.onLayout({});
  assert.deepEqual(log, ['layout', 'layout']);
});

test('safe area insets with the previous insets; unchanged insets do not fire', () => {
  const seen: Array<Insets | undefined> = [];
  const c = make();
  c.attach();
  c.registry.addLifecycleCallback('viewSafeAreaInsetsDidChange', (_o, _i, info) => seen.push(info.previousInsets));
  f.insets.forEach((l) => l({ ...f.inset }));
  assert.deepEqual(seen, []);
  f.insets.forEach((l) => l({ top: 47, left: 0, bottom: 34, right: 0 }));
  assert.deepEqual(seen, [{ top: 0, left: 0, bottom: 0, right: 0 }]);
});

test('viewWillTransition with the new size; font scale feeds traitCollectionDidChange', () => {
  const sizes: unknown[] = [];
  const traits: unknown[] = [];
  const c = make();
  c.attach();
  c.registry.addLifecycleCallback('viewWillTransition', (_o, _i, info) => sizes.push(info.size));
  c.registry.addLifecycleCallback('traitCollectionDidChange', (_o, _i, info) => traits.push(info.previousFontScale));
  f.dim.forEach((l) => l({ window: { width: 800, height: 400, fontScale: 1 } }));
  assert.deepEqual(sizes, [{ width: 800, height: 400 }]);
  f.dim.forEach((l) => l({ window: { width: 800, height: 400, fontScale: 1.3 } }));
  assert.deepEqual(traits, [1]);
  assert.equal(sizes.length, 1);
});

test('color scheme change with the previous scheme', () => {
  const prev: unknown[] = [];
  const c = make();
  c.attach();
  c.registry.addLifecycleCallback('traitCollectionDidChange', (_o, _i, info) => prev.push(info.previousColorScheme));
  f.app.forEach((l) => l({ colorScheme: 'dark' }));
  assert.deepEqual(prev, ['light']);
});

test('memory warning fires on iOS, never subscribes on Android', () => {
  const ios = make('ios');
  ios.attach();
  ios.registry.addLifecycleCallback('didReceiveMemoryWarning', () => log.push('mem'));
  f.mem.forEach((l) => l());
  assert.deepEqual(log, ['mem']);
  owner = {};
  f = new Fakes();
  const android = make('android');
  android.attach();
  android.registry.addLifecycleCallback('didReceiveMemoryWarning', () => log.push('mem2'));
  assert.equal(f.mem.length, 0);
});

test('sources are subscribed lazily and all removed on detach', () => {
  const c = make();
  c.attach();
  assert.equal(f.dim.length + f.app.length + f.mem.length + f.insets.length + f.nav.size, 0);
  c.registry.addLifecycleCallback('viewWillTransition', () => {});
  c.registry.addLifecycleCallback('viewWillAppear', () => {});
  assert.equal(f.dim.length, 1);
  c.detach();
  assert.equal(f.dim.length + [...f.nav.values()].flat().length, 0);
});

test('detach runs teardown blocks in order, once, and detach twice is harmless', () => {
  const c = make();
  c.attach();
  c.registry.addDeallocCallback(() => log.push('a'));
  c.registry.addDeallocCallback(() => log.push('b'));
  c.detach();
  c.detach();
  assert.deepEqual(log, ['a', 'b']);
});

test('manual end after the body beside automatic afterSuper', () => {
  const c = make();
  c.attach();
  c.registry.setManualLifecycleDispatch(true, ['viewDidLayoutSubviews'], ['end']);
  c.registry.addLifecycleCallback('viewDidLayoutSubviews', () => log.push('end-block'), { timing: 'end', key: 'cyl.core.layoutBlock', invokeOnce: true });
  c.registry.addLifecycleCallback('viewDidLayoutSubviews', () => log.push('after'));
  c.onLayout();
  assert.deepEqual(log, ['after']);
  c.registry.invokeLifecycleCallbacks('viewDidLayoutSubviews', 'end');
  assert.deepEqual(log, ['after', 'end-block']);
});

const APPEAR = ['viewWillAppear', 'viewIsAppearing', 'viewDidAppear'] as const;
const names = () => log.filter((l) => l.endsWith('afterSuper')).map((l) => l.split('/')[0]);

test('appear order holds when focus arrives before transitionStart', () => {
  const c = make('ios', [...APPEAR]);
  c.attach();
  f.emit('focus');
  f.emit('transitionStart', { data: { closing: false } });
  f.emit('transitionEnd', { data: { closing: false } });
  assert.deepEqual(names(), [...APPEAR]);
});

test('appear order holds when transitionStart arrives before focus', () => {
  const c = make('ios', [...APPEAR]);
  c.attach();
  f.emit('transitionStart', { data: { closing: false } });
  f.emit('focus');
  f.emit('transitionEnd', { data: { closing: false } });
  assert.deepEqual(names(), [...APPEAR]);
});

test('tab navigator events without data count as appear (bottom-tabs sends data: undefined)', () => {
  const c = make('ios', [...APPEAR]);
  c.attach();
  f.emit('transitionStart');
  f.emit('transitionEnd');
  assert.deepEqual(names(), [...APPEAR]);
});

test('immediate mode: focus fires will, isAppearing, did; blur fires will and did disappear', () => {
  const c = make('ios', [...APPEAR, 'viewWillDisappear', 'viewDidDisappear'], 'immediate');
  c.attach();
  assert.equal([...f.nav.keys()].includes('transitionStart'), false, 'no transition listener in immediate mode');
  f.emit('focus');
  assert.deepEqual(names(), [...APPEAR]);
  f.emit('blur');
  assert.deepEqual(names(), [...APPEAR, 'viewWillDisappear', 'viewDidDisappear']);
  f.emit('focus');
  assert.equal(names().length, 8, 'a second focus runs the sequence again');
});

test('blur in stack mode opens disappear; transitionEnd closes it', () => {
  const c = make('ios', ['viewWillDisappear', 'viewDidDisappear']);
  c.attach();
  f.emit('blur');
  f.emit('transitionStart', { data: { closing: true } });
  assert.deepEqual(names(), ['viewWillDisappear']);
  f.emit('transitionEnd', { data: { closing: true } });
  assert.deepEqual(names(), ['viewWillDisappear', 'viewDidDisappear']);
});

test('mount, unmount, mount subscribes again (React StrictMode)', () => {
  const first = mountLifecycle(owner, f.sources());
  first.controller.registry.addLifecycleCallback('viewWillTransition', () => log.push('transition'));
  assert.equal(f.dim.length, 1);
  first.unmount();
  assert.equal(f.dim.length, 0);
  const second = mountLifecycle(owner, f.sources());
  assert.equal(f.dim.length, 1, 'the second mount subscribed again for the block that is still registered');
  f.dim.forEach((l) => l({ window: { width: 1, height: 2, fontScale: 1 } }));
  assert.deepEqual(log, ['transition']);
  second.unmount();
  assert.equal(f.dim.length, 0);
});
