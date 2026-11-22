'use strict';
const { LifecycleRegistry, EVENTS, TIMINGS } = require('./registry');
const { MiniProgramController } = require('./controller');
const { withLifecycle, withComponentLifecycle, controllerOf } = require('./wrap');

module.exports = { LifecycleRegistry, EVENTS, TIMINGS, MiniProgramController, withLifecycle, withComponentLifecycle, controllerOf };
