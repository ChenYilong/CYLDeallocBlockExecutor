# GitHub issues

Every issue of [ChenYilong/CYLDeallocBlockExecutor](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues), mapped to the API, test or document that resolves it. Task log: [Lifecycle-Callbacks.md](Lifecycle-Callbacks.md#task-log).

## Score

Score = rows whose third column is not TODO ÷ all rows × 100. A row counts only when the third column names evidence: an API plus a test, a README line, or a merged pull request.

| Pass | Date | Rows done | Score | Scored by |
| :-- | :-- | :-- | :-- | :-- |
| 1 (search existing code) | 2026-11-22 | 4 / 7 | 57 / 100 | self, to be reviewed by the advisor |
| 2 (after fixes, commit `dba8386`) | 2026-11-22 | 7 / 7 | 100 / 100 | self, to be reviewed by the advisor |
| 3 (review: 1.3.0 source checked, iOS 17.5 run, docs fixed) | 2026-11-22 | 7 / 7 | 100 / 100 | advisor (provisional, pending CI) |
| 4 (final: CI green on `988faf5`, run [45002539468](https://github.com/ChenYilong/CYLDeallocBlockExecutor/actions/runs/45002539468); transcriptions posted) | 2026-11-22 | 7 / 7 | 100 / 100 | advisor |

## Table

States checked against GitHub on 2026-11-27: all 7 issues are closed (#5, #7 and #8 on 2026-11-22); no issue is open.

"1.3.0" means the published Objective-C release (tag `1.3.0`, CocoaPods). "`master`" means merged but not tagged or published: the Swift port. "PR #12" means the unmerged branch `feat/lifecycle-callbacks` (1.4.0, not published).

| Issue (state, related) | Feature description | API or feature |
| :-- | :-- | :-- |
| [#1](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/1) closed | The README's "update without updating the spec repo" command must use `--no-repo-update` (`--verbose` only prints details). | README.md: `pod update --verbose --no-repo-update` (fixed in commit 54d1c02, released). |
| [#3](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/3) closed, PR [#4](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/4) | Calling `cyl_executeAtDealloc` several times on one object: every block runs, and only when the object deallocates (an earlier block must not run when a new one is added). | API: `cyl_executeAtDealloc(_:)` (deprecated, 1.2.0) and `cylWillDealloc(selfCallback:)`. Tests in `Tests/LifecycleTests/main.swift` section 21: "issue #3: cyl_executeAtDealloc x3, no block runs when a later one is added", "issue #3: cyl_executeAtDealloc x3, every block runs exactly once at dealloc", "issue #3: cylWillDealloc(selfCallback:) adding a runs no block" (also b, c), "issue #3: cylWillDealloc(selfCallback:) x3 runs every block exactly once, in order". No library change was needed. |
| [#5](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/5) closed (2026-11-22) | What the identifier is for and what value to pass to cancel a block: the add call returns it; blocks run in identifier order. | API: `cylWillDealloc(selfCallback:)` / `cylWillDealloc(callback:)` return the identifier, `cylCancelDeallocCallback(identifier:)` takes it; library change: it now returns false when no block has that identifier (before: true for every non-zero value). README "### 取消回调" (what to pass, 0 is `cylDeallocCallbackIllegalIdentifier` and never returned, ascending order from 1, cancel later tasks by comparing identifiers, keyed blocks new in 1.4.0) and the migration table (`cylDeallocCallbackIllegalIdentifier`). Tests (section 22): "issue #5: identifiers ascend from 1, never 0", "issue #5: cancel(identifier:) returns true once, then false", "issue #5: cancel(identifier: 0) returns false", "issue #5: cancelling every identifier above the first returns true", "issue #5: cancelled later tasks do not run, the earlier one does". |
| [#6](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/6) closed | Comment on the theme (skin) timing in the README; no defect reported. | No change needed. README "theme" example: the setter registers `cylWillDealloc` to remove the observer (released). |
| [#7](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/7) closed (2026-11-22), related [#8](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/8) | A Swift implementation: several destroy events per object, added under a lock, each called with the object. | Swift port merged in PRs [#10](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/10) and [#11](https://github.com/ChenYilong/CYLDeallocBlockExecutor/pull/11) (on `master`, not tagged or published yet): `cylWillDealloc(selfCallback:)`. Differences from the issue's snippet: one lock per object, the owner is `Unmanaged<AnyObject>` instead of `unowned(unsafe)`, blocks have ordered identifiers and can be cancelled, and the API extends `NSObject` only (the snippet accepts any `AnyObject`, including pure Swift classes). Tests: the dealloc checks in `Tests/LifecycleTests/main.swift` (e.g. "issue #3: cylWillDealloc(selfCallback:) x3 runs every block exactly once, in order"). The screenshot is transcribed below. |
| [#8](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/8) closed (2026-11-22), related [#7](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/7) | A view observes its view controller's `view` with KVO; on iOS 11+ the view controller deallocates before the view, so the observer must be removed when the view controller deallocates (release order, not a reference cycle). | API: `cylWillDealloc(selfCallback:)` on the view controller removes the KVO observer and clears the observer's reference. README "### 观察者比被观察的控制器活得久（issue #8）". Tests (section 23, once with the view loaded and once not loaded): "issue #8 (view loaded|view not loaded): the view controller's dealloc block ran", "...: the observer's view controller reference is nil", "...: the observer outlives the view controller without a crash", "...: the observer deallocates afterwards". |
| [#9](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/9) closed | A comment that says `dispatch_barrier_async` needs a concurrent queue while the code creates a serial one. | Resolved by the Swift port (`master`): the comment was in this repository's 1.3.0 `NSObject+CYLDeallocBlockExecutor.m` (`cyl_deallocCallbackQueue`), and the maintainer agreed it was wrong. The Swift port has no dispatch queue; it guards each object with a lock (`cylDeallocCallbackLock`, `CYLCallbackModel.lock`), so the comment is gone (`grep -rn "dispatch_\|DispatchQueue" CYLDeallocBlockExecutor/ --include='*.swift'` finds nothing). |

## Image transcriptions

The OCR text in #7 and #8 is garbled. The original screenshots are in `assets/`; the transcriptions are posted as new comments on the issues (status below).

| Issue | Screenshot | Comment |
| :-- | :-- | :-- |
| #7 | [assets/issue-7-swift-destruct-event.jpg](assets/issue-7-swift-destruct-event.jpg) | [posted](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/7#issuecomment-7076214017) |
| #8 | [assets/issue-8-kvo-release-order.jpg](assets/issue-8-kvo-release-order.jpg) | [posted](https://github.com/ChenYilong/CYLDeallocBlockExecutor/issues/8#issuecomment-7076214279) |
