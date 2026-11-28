> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# WeChat Mini Program
Plain CommonJS in `MiniProgram/` (registry, center, controller, log, types, index) with hand-kept `typings/*.d.ts`.

## DevTools constraints (enforced by test/syntax.test.js)
- DevTools' es6 compile **silently drops a module** containing `?.(`, logical assignment, private fields or class fields; the guard also bans `??`, `?.` and `catch {`. Static fields are assigned after the class.
- The unused-file filter does not follow `...require()` inside an object spread. `index.js` must use plain `require('./name')` calls, without the .js extension; every module must be reachable.
- `WeakRef` may be missing: `cylWeakRef` then holds the object **strongly**.

The example project sets `es6: false` in `project.config.json`, so a run of the example alone does not exercise the es6 compile that the guard protects against; a consumer app with es6 on does.

## Controller mapping
| Event | Source |
|---|---|
| window moves (owner as window), willMoveToParent, viewDidLoad, didMoveToParent | onLoad |
| viewWillAppear, viewIsAppearing | onShow |
| viewDidAppear, didEnterScreen | onReady the first time, then right after onShow |
| disappear events, didLeaveScreen | onHide |
| viewWillTransition | onResize (size may be nested under .size) |
| traitCollectionDidChange | themeChanged(theme); the first value is only a baseline |
| didReceiveMemoryWarning | memoryWarning() |
| screen visibility of a node | observeScreen(selector) via IntersectionObserver |
| scroll events | onPageScroll; 150 ms of quiet (scrollEndDelay) ends it, willDecelerate false |
| teardown | onUnload |

No source: layout events, safe-area insets, layout margins.

## withLifecycle(options)
Wraps **Page** options: onLoad, onShow, onReady, onHide, onUnload, onResize, onPageScroll. The controller runs **before** the original for onLoad and **after** it for the rest, so blocks added inside onLoad miss the load events. Register on `LifecycleRegistry.of(page)` before onLoad. The controller is `page.cylController`. Theme and memory callbacks must be forwarded by hand.

## Example and DevTools runner
- `sync.sh` copies the library into `miniprogram/cyl/` (git-ignored): a mini program cannot require files outside its root.
- `run-devtools.mjs` drives DevTools with miniprogram-automator. Needs a logged-in DevTools, the service port and an accepted appid (`CYL_APPID`; the config file is restored afterwards).
- Windows: Node refuses to spawn `cli.bat` without a shell, so the runner starts `cli auto --trust-project` through a shell, connects to port 9420 and polls for the first page.
- `Page.callMethod` failed on DevTools 2.02 Windows, so the runner uses `mini.evaluate`. Theme and resize are **forwarded calls**, not real system events.
- `no-happy-eyeballs-proxy.mjs`: on a high-latency link DevTools' Node address racing times out; this local proxy works around it.
- The demo never calls wx.offThemeChange / offMemoryWarning, and its global observer closes over the page (demo only) [read].

## Tests
`node --test "test/*.test.js"`: 65 / 65 pass, headless.
