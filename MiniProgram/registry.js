'use strict';
// CommonJS, no build step: the Mini Program loads this file as it is.

const EVENTS = [
  'viewDidLoad', 'viewWillAppear', 'viewIsAppearing', 'viewDidAppear', 'viewWillLayoutSubviews',
  'viewDidLayoutSubviews', 'viewWillDisappear', 'viewDidDisappear', 'viewSafeAreaInsetsDidChange',
  'viewLayoutMarginsDidChange', 'traitCollectionDidChange', 'viewWillTransition', 'willMoveToParent',
  'didMoveToParent', 'didReceiveMemoryWarning',
];
const TIMINGS = ['beforeSuper', 'afterSuper', 'end'];

const registries = new WeakMap();

/**
 * One registry per owner (a Page or Component instance, or any object): the
 * lifecycle blocks and the teardown blocks. The iOS rules, see
 * `docs/Lifecycle-Callbacks.md`: one identifier counter for every block; blocks
 * run in identifier order from a snapshot, so a block can add or cancel blocks;
 * a key replaces the block added before under it (the new block starts
 * unfired; keys are separate for lifecycle and teardown blocks); keyed blocks
 * belong to their key holder, so cancel-all and re-arm by event skip them.
 * No lock: the Mini Program logic layer runs one thread.
 */
class LifecycleRegistry {
  static of(owner) {
    let r = registries.get(owner);
    if (!r) {
      r = new LifecycleRegistry(owner);
      registries.set(owner, r);
    }
    return r;
  }

  constructor(owner) {
    this._owner = new WeakRef(owner);
    this._entries = [];
    this._next = 1;
    this._manual = new Set();
    this._depth = new Map();
    /** Called after a block is added for an event (the controller subscribes lazily). */
    this.onRegister = undefined;
    /** The controller sets this once its automatic hooks fire `beforeSuper` / `afterSuper`. */
    this.hookInstalled = false;
  }

  get blockCount() { return this._entries.filter((e) => !e.cancelled).length; }

  hasBlocksFor(event) { return this._entries.some((e) => e.event === event && !e.cancelled); }

  _drop(match) {
    for (const e of this._entries) if (match(e)) e.cancelled = true;
    this._entries = this._entries.filter((e) => !e.cancelled);
  }

  addLifecycleCallback(event, callback, options = {}) {
    if (!EVENTS.includes(event)) throw new Error(`unknown event ${event}`);
    const { timing = 'afterSuper', invokeOnce = false, key } = options;
    if (key !== undefined) this._drop((e) => e.key === key && e.event !== null);
    const identifier = this._next++;
    this._entries.push({ identifier, callback, event, timing, invokeOnce, key, fired: false, cancelled: false });
    if (this.onRegister) this.onRegister(event);
    return identifier;
  }

  /** target: `{ identifier }` or `{ key }`; true when a block was removed. */
  cancelLifecycleCallback(target) { return this._cancelOne(target, false); }

  cancelAllLifecycleCallbacks(event, timing) {
    this._drop((e) => e.event === event && e.key === undefined && (timing === undefined || e.timing === timing));
  }

  rearmLifecycleCallbacks(event, timing) {
    for (const e of this._entries) {
      if (e.event === event && e.key === undefined && (timing === undefined || e.timing === timing)) e.fired = false;
    }
  }

  rearmLifecycleCallback(key) {
    for (const e of this._entries) if (e.event !== null && e.key === key) e.fired = false;
  }

  addDeallocCallback(callback, options = {}) {
    const { key } = options;
    if (key !== undefined) this._drop((e) => e.key === key && e.event === null);
    const identifier = this._next++;
    this._entries.push({ identifier, callback, event: null, timing: 'end', invokeOnce: false, key, fired: false, cancelled: false });
    return identifier;
  }

  cancelDeallocCallback(target) { return this._cancelOne(target, true); }

  cancelAllDeallocCallbacks() { this._drop((e) => e.event === null && e.key === undefined); }

  _cancelOne(target, dealloc) {
    const hit = this._entries.find((e) => (e.event === null) === dealloc &&
      ('identifier' in target ? e.identifier === target.identifier : e.key === target.key));
    if (!hit) return false;
    hit.cancelled = true;
    this._entries = this._entries.filter((e) => e !== hit);
    return true;
  }

  /** Runs the teardown blocks in identifier order, once. The owner calls this when it is torn down. */
  runDealloc() {
    const owner = this._owner.deref();
    if (owner === undefined) return;
    const snapshot = this._entries.filter((e) => e.event === null).sort((a, b) => a.identifier - b.identifier);
    this._entries = this._entries.filter((e) => e.event !== null);
    for (const e of snapshot) {
      if (!e.cancelled) e.callback(owner, e.identifier, { event: null, timing: 'end', isDealloc: true });
    }
  }

  setManualLifecycleDispatch(manual, events, timings = TIMINGS) {
    for (const e of events) for (const t of timings) {
      if (manual) this._manual.add(`${e}/${t}`); else this._manual.delete(`${e}/${t}`);
    }
  }

  isManual(event, timing) { return this._manual.has(`${event}/${timing}`); }

  isAutomatic(event, timing) { return this.hookInstalled && timing !== 'end' && !this.isManual(event, timing); }

  fireAutomatic(event, timing, info = {}) {
    if (this.isManual(event, timing)) return;
    this._fire(event, timing, info);
  }

  invokeLifecycleCallbacks(event, timing, info = {}) {
    if (!this.isManual(event, timing)) {
      throw new Error(`declare ${event} / ${timing} manual with setManualLifecycleDispatch first`);
    }
    this._fire(event, timing, info);
  }

  /**
   * Runs `callSuper`, then `body`, with the timings around them. With the
   * controller's hook the automatic timings come from the hook and this adds
   * `end` after `body`, at the outermost level only and not when `end` is
   * declared manual. Without a hook all three timings fire from the outermost call.
   */
  performLifecycle(event, parts) {
    const depth = this._depth.get(event) || 0;
    const outermost = depth === 0;
    this._depth.set(event, depth + 1);
    try {
      if (!this.hookInstalled && outermost) this.fireAutomatic(event, 'beforeSuper', parts.info);
      parts.callSuper();
      if (!this.hookInstalled && outermost) this.fireAutomatic(event, 'afterSuper', parts.info);
      parts.body();
      if (outermost) this.fireAutomatic(event, 'end', parts.info);
    } finally {
      this._depth.set(event, depth);
    }
  }

  _fire(event, timing, info) {
    const owner = this._owner.deref();
    if (owner === undefined) return;
    const snapshot = this._entries
      .filter((e) => e.event === event && e.timing === timing && !(e.invokeOnce && e.fired))
      .sort((a, b) => a.identifier - b.identifier);
    for (const e of snapshot) {
      if (e.cancelled || (e.invokeOnce && e.fired)) continue;
      if (e.invokeOnce) e.fired = true;
      e.callback(owner, e.identifier, Object.assign({}, info, { event, timing }));
    }
  }
}

module.exports = { LifecycleRegistry, EVENTS, TIMINGS };
