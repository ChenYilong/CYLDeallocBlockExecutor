'use strict';
const { LifecycleRegistry } = require('./registry');

const sameInsets = (a, b) => a && b && a.top === b.top && a.left === b.left && a.bottom === b.bottom && a.right === b.right;

/**
 * Fires the lifecycle events of a Page or Component for the wrappers in
 * `wrap.js` (or by hand). `wx` is injectable so the controller runs in Node.
 *
 * Mapping (iOS event: Mini Program source):
 * - `viewDidLoad`: `onLoad` (Page) or `attached` (Component);
 * - `viewWillAppear` and `viewIsAppearing`: `onShow`, back to back;
 *   `viewDidAppear`: `onReady` the first time, the next tick after `onShow`
 *   later; foreground and background of the mini program go through
 *   `onShow` / `onHide` too, so they fire these events again (unlike iOS);
 * - `viewWillDisappear` and `viewDidDisappear`: `onHide`, back to back (the
 *   Mini Program has no split);
 * - `viewWillTransition`: `wx.onWindowResize`; `traitCollectionDidChange`:
 *   `wx.onThemeChange`; `didReceiveMemoryWarning`: `wx.onMemoryWarning`;
 *   `viewSafeAreaInsetsDidChange`: the safe area read from
 *   `wx.getWindowInfo()` on `onShow` and on resize (sampled: there is no change
 *   event);
 * - `willMoveToParent` / `didMoveToParent`: `onLoad` / `attached` (true),
 *   `onUnload` / `detached` (false);
 * - not available: `viewWillLayoutSubviews`, `viewDidLayoutSubviews` (no layout
 *   callback), `viewLayoutMarginsDidChange` (no layout margins).
 * Teardown blocks run on `unload()`: deterministic.
 * Sources are subscribed when the first block for them is added and removed on unload.
 */
class MiniProgramController {
  constructor(owner, wx) {
    this.owner = owner;
    this.wx = wx || {};
    this.registry = LifecycleRegistry.of(owner);
    this.registry.hookInstalled = true;
    this.registry.onRegister = (event) => this._subscribeFor(event);
    this._removers = new Map();
    this._loaded = false;
    this._unloaded = false;
    this._shown = false;
    this._didPending = false;
    this._firstReady = false;
    this._lastTheme = undefined;
    this._lastSize = undefined;
    this._lastInsets = undefined;
  }

  _around(event, info, body) {
    const r = this.registry;
    r.fireAutomatic(event, 'beforeSuper', info);
    r.fireAutomatic(event, 'afterSuper', info);
    if (body) body();
    r.fireAutomatic(event, 'end', info); // the body is known here, so `end` is automatic too
  }

  /** `onLoad` / `attached`; `body` is the owner's own handler. */
  load(body) {
    this._loaded = true;
    this._around('willMoveToParent', { parentAttached: true });
    this._around('viewDidLoad', {}, body);
    this._around('didMoveToParent', { parentAttached: true });
    this._subscribeAll();
  }

  /** `onShow`. */
  show(body) {
    this._shown = true;
    this._didPending = true;
    this._around('viewWillAppear', {}, body);
    this._around('viewIsAppearing', {});
    this._sampleInsets();
    if (this._firstReady) {
      const nextTick = this.wx.nextTick ? (f) => this.wx.nextTick(f) : (f) => setTimeout(f, 0);
      nextTick(() => this._didAppear());
    }
  }

  /** `onReady`. */
  ready(body) {
    this._firstReady = true;
    this._around('viewDidAppear', {}, body);
    this._didPending = false;
  }

  _didAppear() {
    if (!this._didPending || this._unloaded) return;
    this._didPending = false;
    this._around('viewDidAppear', {});
  }

  /** `onHide`. */
  hide(body) {
    this._shown = false;
    this._around('viewWillDisappear', {}, body);
    this._around('viewDidDisappear', {});
  }

  /** `onUnload` / `detached`. */
  unload(body) {
    if (this._unloaded) return;
    this._unloaded = true;
    if (body) body();
    this._around('willMoveToParent', { parentAttached: false });
    this._around('didMoveToParent', { parentAttached: false });
    for (const remove of this._removers.values()) remove();
    this._removers.clear();
    this.registry.runDealloc();
  }

  /** `onResize` (page-level hook; the global listener calls the same). */
  resize(size) {
    this._windowResized(size);
  }

  _windowResized(res) {
    const s = res && (res.size || res);
    const size = { width: s.windowWidth !== undefined ? s.windowWidth : s.width, height: s.windowHeight !== undefined ? s.windowHeight : s.height };
    if (!this._lastSize || this._lastSize.width !== size.width || this._lastSize.height !== size.height) {
      this._lastSize = size;
      this._around('viewWillTransition', { size });
    }
    this._sampleInsets();
  }

  _sampleInsets() {
    if (!this.registry.hasBlocksFor('viewSafeAreaInsetsDidChange') || !this.wx.getWindowInfo) return;
    const w = this.wx.getWindowInfo();
    const a = w.safeArea;
    if (!a) return;
    const insets = { top: a.top, left: a.left, bottom: w.screenHeight - a.bottom, right: w.screenWidth - a.right };
    if (this._lastInsets && sameInsets(this._lastInsets, insets)) return;
    const previousInsets = this._lastInsets;
    this._lastInsets = insets;
    if (previousInsets !== undefined) this._around('viewSafeAreaInsetsDidChange', { previousInsets });
  }

  _subscribeAll() {
    for (const e of ['viewWillTransition', 'traitCollectionDidChange', 'didReceiveMemoryWarning', 'viewSafeAreaInsetsDidChange']) {
      if (this.registry.hasBlocksFor(e)) this._subscribeFor(e);
    }
  }

  _subscribeFor(event) {
    if (!this._loaded || this._unloaded) return;
    const wx = this.wx;
    const add = (name, on, off, handler) => {
      if (this._removers.has(name) || typeof wx[on] !== 'function') return;
      wx[on](handler);
      this._removers.set(name, () => wx[off] && wx[off](handler));
    };
    switch (event) {
      case 'viewWillTransition':
        add('resize', 'onWindowResize', 'offWindowResize', (res) => this._windowResized(res));
        if (wx.getWindowInfo && !this._lastSize) {
          const w = wx.getWindowInfo();
          this._lastSize = { width: w.windowWidth, height: w.windowHeight };
        }
        break;
      case 'viewSafeAreaInsetsDidChange':
        if (wx.getWindowInfo && !this._lastInsets) this._sampleInsets();
        add('resize', 'onWindowResize', 'offWindowResize', (res) => this._windowResized(res));
        break;
      case 'traitCollectionDidChange':
        if (wx.getAppBaseInfo && this._lastTheme === undefined) this._lastTheme = wx.getAppBaseInfo().theme;
        add('theme', 'onThemeChange', 'offThemeChange', (res) => {
          const previousTheme = this._lastTheme;
          this._lastTheme = res.theme;
          this._around('traitCollectionDidChange', { previousTheme });
        });
        break;
      case 'didReceiveMemoryWarning':
        add('memory', 'onMemoryWarning', 'offMemoryWarning', (res) => this._around('didReceiveMemoryWarning', { level: res && res.level }));
        break;
      default:
    }
  }
}

module.exports = { MiniProgramController };
