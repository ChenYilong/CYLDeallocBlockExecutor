> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# Design history and lessons (from docs/Lifecycle-Callbacks.md, Cross-Platform-API.md, Issues.md)
All statements here are what the documents record [doc].

## Requests that shaped the library (task log, 2026-11-22 to 2026-11-27)
| When | Request | Outcome recorded |
|---|---|---|
| 11-22 | Lifecycle blocks like the dealloc block, as a core dependency for CYLTabBarController; top / bottom and before / after super chosen by parameter | designs v1 to v4, score 100 (29 / 29) |
| 11-22 | CI checks | five jobs green on macos-26; pushing the workflow needed the workflow scope (SSH push worked) |
| 11-22 | Example scene life cycle and Carthage | done (iOS 27 requires a scene manifest) |
| 11-22 | Re-evaluate prefixes after SonarCloud findings on CYLTabBarController | camelCase cylFoo for extension members; CYL types kept; shims for 1.3.0 names |
| 11-22 | Resolve the GitHub issues | 7 / 7 rows |
| 11-23 | All-platform interfaces with a scored table | 205 / 205 cells after the design v5 rows and logging rows |
| 11-23 | Observe badge, animation and scroll moments | design v5 |
| 11-24 | Advisor re-score and push to 100 | device runs, effect score |
| 11-26 | appDidBecomeActiveOnScreen (requested for CYLSearchViewController) | iOS only, 89 / 89 |
| 11-27 | Mini Program in DevTools on Windows; round 19 handoff | 11 / 11 DevTools rows; runs delegated |

## Design versions and why
- **v1:** timings relative to the super call that reaches UIKit; one model and one identifier counter per object; blocks run outside locks; dealloc stays out of the typed API because a typed owner would be retained while being destroyed; hooks keep the previous IMP so other swizzles keep working.
- **v2 (CYLTabBarController needs):** the core registers .afterSuper / .beforeSuper, never .end, so app subclasses cannot silently break it; manual dispatch per (event, timing); replace by key; capture the observed object in dealloc blocks.
- **v3 (nested overrides):** v2 fired blocks twice or out of order with two overriding levels. Now the hook always brackets UIKit; perform fires .end only at the outermost level. Limitation: a UIKit class whose override skips super never reaches the hook (seen: UINavigationController.viewDidLayoutSubviews).
- **v4 (core / app isolation):** keyed blocks belong to the key holder; cancel-all and re-arm by event skip them. Prefix cyl.core. is a convention only.
- **v5 (observable moments):** the library knows only generic concepts (window, screen, scroll, custom events, global observers, forwarding). Badges stay in CYLTabBarController, which posts them as custom events.

## Bugs found on real runs, with their lesson
| Bug | Cause | Lesson |
|---|---|---|
| iOS: no scrollDidEndScrolling after a flick | UIKit clears isDecelerating after the last contentOffset change | poll for the end; KVO cannot see it |
| iOS: global scroll observer added late saw nothing | scroll views already on screen were not observed | attach on subscription |
| iOS: one drag heard five times by a global observer (CI) | one call per subscribed subview | notify the center once per scroll view |
| Forwarding made global observers fire twice | source and target both dispatched | forwarded fires skip the center |
| Android: configuration changes arrived one step late | activity resources are stale inside the Application callback; two Robolectric tests hid it | read newConfig; make tests mimic device ordering |
| HarmonyOS: first dark-mode switch missed; stale color mode | no seeded baseline; context.config is old during the callback | seed the baseline; read newConfig |
| HarmonyOS HAR did not build | imports outside the module (ArkTS 00309001) | sources live inside the module |
| React Native and Flutter: popped or replaced screen went straight to teardown | no blur / didPop on removal | teardown sends the disappear events first |
| Mini Program: module silently missing in DevTools | es6 compile drops optional call, class fields and the like | static syntax guard |
| Mini Program: undefined size on resize | system event nests size | unwrap the payload |

Pattern: several of these passed headless tests and appeared only on a device or in the real tool.

## GitHub issues (docs/Issues.md)
#1 README command; #3 several blocks run only at dealloc; #5 identifier meaning (cancel now returns false for unknown identifiers); #6 comment only; #7 Swift port; #8 observer outliving the observed controller (release order, not a retain cycle); #9 obsolete queue comment removed with the Swift port. Screenshots for #7 and #8 were transcribed onto the issues. "1.3.0" is the published Objective-C release.

## Integration notes for CYLTabBarController
Lifecycle-Callbacks.md maps its overrides and layout block onto this API, with keys beginning cyl.core. Scenario-Theme-CYLTabBarController.md shows theme switching on six platforms (pair the observer with a keyed teardown block; re-apply on traitCollectionDidChange; re-arm only the keyed layout block). Its snippets are marked illustrative and not compiled.
