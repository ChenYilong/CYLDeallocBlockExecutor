> **Not reviewed.** AI-generated notes on commit `505d187`; the maintainer has not checked them. Of the findings, only what is marked reproduced / `[probe]` was reproduced by running code; `[read]`, `[doc]` and `[unverified]` statements were not run.

# CYLDeallocBlockExecutor: codebase knowledge export
Produced by `/claude-mem:learn-codebase` on 2026-11-29 (Windows), in two passes. Branch `test/miniprogram-devtools-windows` at `505d187`. The reading pass changed no repo file. The notes were first written outside the repository and moved to `docs/learn-codebase/` on 2026-11-29.

These notes are a snapshot of that commit. Most findings come from reading the code and have not been reviewed or reproduced; check the code before acting on one.

## What the library is
Lifecycle and teardown ("dealloc") blocks for any object. iOS (Swift, 1.4.0, iOS 15+) is the reference. Ports: Android, Flutter, HarmonyOS, React Native, WeChat Mini Program.

**Start with:** 01 (design), then 09 (findings).

## Files
| File | Contents |
|---|---|
| 01-architecture.md | Shared registry rules, delivery order, timings, events |
| 02-ios.md | iOS (Swift) |
| 03-android.md | Android: core and binding |
| 04-flutter.md | Flutter |
| 05-harmonyos.md | HarmonyOS |
| 06-react-native.md | React Native |
| 07-miniprogram.md | WeChat Mini Program |
| 08-cross-platform-matrix.md | Event sources and behaviour differences |
| 09-findings.md | F1 to F17: bugs, risks and doc drift, with evidence level; revised in pass two |
| 10-tests-catalog.md | Test names with line numbers |
| 11-build-ci-scripts.md | Build, CI, scripts, workarounds, test handoff |
| 12-repo-rules.md | Working, commit and naming rules |
| 13-design-history.md | Requests, designs v1 to v5, bugs found on real runs and their lessons |
| 14-device-evidence-and-scores.md | What has run on devices, score history, tooling facts |
| 15-examples-and-tests.md | Example apps, demos and test harnesses |
| 16-config-and-project-files.md | Versions, project and manifest settings, leftovers |
| api-index.md | Declarations in each library source file, with line numbers |
| file-inventory.tsv | The 133 source files with size and line count |
| file-inventory-all.tsv | All 371 tracked files with read status |
| probes/ | Two reproduction scripts and their output |

## Coverage of the 371 tracked files
| Category | Files | Status |
|---|---|---|
| Source | 133 | read in full |
| Docs (Markdown) | 18 | read in full (pass two finished them) |
| Config and manifests | 87 | read in full (pass two) |
| Generated (project files, per-user Xcode data, storyboards, asset catalogs, Gradle wrapper scripts) | 33 | skipped on purpose; only key settings pulled from the project.pbxproj files |
| Binaries (images, jars, keystore and so on) | 100 | not opened, screenshots included |

Not covered: other branches and git history beyond the recent log, GitHub issues and PRs online, and the CYLTabBarController repository.

## What was run
| Check | Result on 2026-11-29 (Node v22.23.5, pass one) |
|---|---|
| React Native Node suite | 56 / 56 pass |
| HarmonyOS Node suite | 47 / 47 pass |
| Mini Program Node suite | 65 / 65 pass |
| Two probes | see probes/ (the teardown-cancel probe shows behaviour that matches the iOS doc, see F1) |

**Not run:** iOS, Android and Flutter tests, any device, simulator or WeChat DevTools run.

## Evidence labels
- **[probe]** reproduced by running code. **[read]** follows from source or docs, not executed. **[unverified]** depends on platform behaviour not checked. **[doc]** a repo document says so; not re-checked.
