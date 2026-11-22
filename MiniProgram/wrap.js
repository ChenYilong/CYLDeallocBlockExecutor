'use strict';
const { MiniProgramController } = require('./controller');

const controllers = new WeakMap();

function controllerOf(instance, wx) {
  let c = controllers.get(instance);
  if (!c) {
    c = new MiniProgramController(instance, wx);
    controllers.set(instance, c);
  }
  return c;
}

function call(options, name, self, args) {
  return typeof options[name] === 'function' ? options[name].apply(self, args) : undefined;
}

/**
 * Wraps the options of a `Page({...})`: the Page's own handlers become the body
 * the timings surround (`beforeSuper` and `afterSuper` before the handler,
 * `end` after it). Add blocks in `options.lifecycle(registry, page)`, which runs
 * before `onLoad` fires anything (so `viewDidLoad` blocks fit), or later through
 * `LifecycleRegistry.of(page)`. `env.wx` is injectable (tests).
 */
function withLifecycle(options, env = {}) {
  const wx = env.wx || (typeof globalThis !== 'undefined' ? globalThis.wx : undefined);
  const wrapped = Object.assign({}, options);
  wrapped.onLoad = function onLoad(...args) {
    const c = controllerOf(this, wx);
    if (typeof options.lifecycle === 'function') options.lifecycle(c.registry, this);
    c.load(() => call(options, 'onLoad', this, args));
  };
  wrapped.onShow = function onShow(...args) { controllerOf(this, wx).show(() => call(options, 'onShow', this, args)); };
  wrapped.onReady = function onReady(...args) { controllerOf(this, wx).ready(() => call(options, 'onReady', this, args)); };
  wrapped.onHide = function onHide(...args) { controllerOf(this, wx).hide(() => call(options, 'onHide', this, args)); };
  wrapped.onUnload = function onUnload(...args) { controllerOf(this, wx).unload(() => call(options, 'onUnload', this, args)); };
  wrapped.onResize = function onResize(...args) {
    call(options, 'onResize', this, args);
    controllerOf(this, wx).resize(args[0]);
  };
  return wrapped;
}

/**
 * Wraps the options of a `Component({...})`: `lifetimes.attached` / `ready` /
 * `detached` and `pageLifetimes.show` / `hide` / `resize`.
 */
function withComponentLifecycle(options, env = {}) {
  const wx = env.wx || (typeof globalThis !== 'undefined' ? globalThis.wx : undefined);
  const life = options.lifetimes || {};
  const page = options.pageLifetimes || {};
  const wrapped = Object.assign({}, options);
  wrapped.lifetimes = Object.assign({}, life, {
    attached(...a) {
      const c = controllerOf(this, wx);
      if (typeof options.lifecycle === 'function') options.lifecycle(c.registry, this);
      c.load(() => call(life, 'attached', this, a));
    },
    ready(...a) { controllerOf(this, wx).ready(() => call(life, 'ready', this, a)); },
    detached(...a) { controllerOf(this, wx).unload(() => call(life, 'detached', this, a)); },
  });
  wrapped.pageLifetimes = Object.assign({}, page, {
    show(...a) { controllerOf(this, wx).show(() => call(page, 'show', this, a)); },
    hide(...a) { controllerOf(this, wx).hide(() => call(page, 'hide', this, a)); },
    resize(...a) { call(page, 'resize', this, a); controllerOf(this, wx).resize(a[0]); },
  });
  return wrapped;
}

module.exports = { withLifecycle, withComponentLifecycle, controllerOf };
