# CYLDeallocBlockExecutor folder instructions

Read this file before reading or writing files in this repository. It inherits the vault's root `instructions.md`.

## Where the rules are

- This file: the repository rules.
- `.agents/skills/cyl-naming/SKILL.md`: how to name new code (the rules below, as a skill).
- `.agents/skills/cyl-example-demo/SKILL.md`: how a demo example shows sectioned lists (the "Example demo" rule below, as a skill).
- `docs/Lifecycle-Callbacks.md`: the task log, the API design and the score.

## Working rules

- Write repository instructions, skills, docs, code comments and commit messages in English.
- Log every task in `docs/` before starting it (TODO, then DONE), with the user's prompt verbatim.
- Commits: Commitizen style, English only, body line `By  @ChenYilong <luohanchenyilong@163.com>`. Never commit `._*` files.
- Tests: `bash Tests/run-lifecycle-tests.sh <simulator UDID>` (Debug) and with `CYL_TEST_CONFIGURATION=release`; `pod lib lint`; CI is `.github/workflows/ci.yml`.

## Naming: prefixes after the static analysis (2026-11-22)

Re-evaluated with SonarCloud's report on CYLTabBarController PR #788 (956 open issues: 743 `swift:S100`, 146 `swift:S115`, 16 `S116`, 11 `S117`, 3 `S101`). Sonar's default Swift formats: functions `^[a-z][a-zA-Z0-9]*$` (S100), constants the same (S115), classes `^[A-Z][a-zA-Z0-9]*$` (S101). `cyl_foo` fails S100; `cylFoo` and `CYLFoo` pass.

### Why the prefixes existed

- Objective-C categories: a category method with the same selector as another category's method replaces it at run time, silently. The `cyl_` prefix keeps our selectors apart.
- Objective-C has one global class namespace: two classes with the same name collide. The `CYL` prefix keeps our classes apart.

### What Swift changes, and what it does not

| Kind of name | Rule | Why |
| :-- | :-- | :-- |
| Types (class, struct, enum, protocol, typealias) | Keep `CYL` | Swift types live in their module, but `@objc` classes and every `NSObject` subclass are registered in the Objective-C runtime by name, which is still one global namespace. `CYLFoo` passes S101. A module named like one of its types (`CYLTabBarController`) breaks `Module.Type` qualification, so the prefix is the reliable way to tell types apart. |
| Members of our own types | No prefix: `event`, `invoke(for:)` | The type is the namespace. |
| Members added in extensions of types we do not own (`NSObject`, `UIViewController`, `UIView`, `UITabBarItem`) | Prefix in camelCase: `cylWillDealloc(…)`; add `@objc(cyl_willDealloc…)` when the member must stay visible to Objective-C | Two modules can add the same member to the same system type; Swift has no stable syntax to pick an extension member by module, so the call becomes ambiguous. An `@objc` extension member is a category method and can replace another one at run time, exactly as in Objective-C. camelCase passes S100; the `@objc` name keeps the Objective-C selector unchanged. |
| Global constants and functions | `cylFoo` (camelCase), or a static member of a `CYL` type | S115 / S100. A global in a module can still clash at call sites that import two modules. |
| Released names (`cyl_willDealloc(selfCallback:)`, `cyl_cancelDeallocCallback(identifier:)`, `cyl_cancelAllDeallocCallbacks()`, `CYLDeallocCallbackIllegalIdentifier`, 1.3.0) | Keep as `@available(*, deprecated, renamed:)` shims that forward to the new name | Existing callers keep compiling with a fix-it. Sonar still reports the shims; accept those few issues until a major release removes them. Unreleased names (everything new in 1.4.0) are renamed without shims. |
| Objective-C selectors and Objective-C headers | Unchanged (`cyl_`, `CYL`) | The Objective-C rules above still hold, and changing a selector breaks callers. |

### Other languages (guidance; check each platform before relying on it)

- Kotlin / Java (Android): packages namespace classes; extension functions are resolved statically and can be renamed on import (`import … as …`). No class or extension prefix is needed for collisions. Android resources (layouts, drawables, strings, styles, attributes) are merged into the app's single namespace: keep a resource prefix (`cyl_`, Gradle `resourcePrefix`).
- Dart (Flutter): libraries namespace everything, `import … as` and `hide` resolve clashes, extensions are named. No prefix needed for collisions; platform channel names and asset paths are global strings: keep a prefix there.
- ArkTS (HarmonyOS) and JavaScript / TypeScript (React Native, WeChat Mini Program): ES modules namespace code. Global names still clash: custom component tags, global CSS class names, native module names, event names, storage keys, resource names. Keep a prefix on those.

### Applied in this repository (1.4.0)

`cyl_addLifecycleCallback` → `cylAddLifecycleCallback`, and the same for every member listed in [docs/Lifecycle-Callbacks.md](docs/Lifecycle-Callbacks.md); the 1.3.0 names above stay as deprecated shims; `CYLLifecycleEvent`, `CYLLifecycleTiming`, `CYLLifecycleInfo`, `CYLDeallocCallback` keep their names.

## Example demo: sectioned lists use the ClassifyMenu tag list (2026-11-25)

Category: example demos (every example layer of this repository). This file has far fewer than 200 lines, so the rule lives here; the skill `.agents/skills/cyl-example-demo/SKILL.md` repeats it as a checklist. When they disagree, this file wins; fix the skill.

- **When:** a demo screen needs a table-view style with sections (grouped rows). Do not build a grouped table; use the tag list of CollectionViewClassifyMenu (`CYLTagListView`), one tag per row, the row's main title and icon as the tag's title and image.
- **Sections:** use the tag list's section style. Every section header has a title; an empty title is a bug.
- **Fold:** a section with more rows than the maximum shows a fold button, "More" or "Less" with the built-in icon (the tag list's fold control, `defaultVisibleRows`). In this repository's example the maximum is 3 rows.
- **Tap:** tapping a tag does exactly what tapping the old cell did (same navigation, same logs).
- **Long press:** a long press on a tag shows the row's subtitle in a small floating box with an arrow, through the tag list's long-press API (`tagLongPressHandler`). On iPhone the popover must stay a popover (`adaptivePresentationStyle` returns `.none`), not a sheet.
- **Wrapping and width:** tag titles may wrap to more lines (the style's title-wrap API, `CYLMenuStyle.titleWraps`); never a one-line limit. Tag width is adaptive, so one row holds as many tags as fit.
- **Core first:** when the tag list lacks an API, add it in CollectionViewClassifyMenu (its own repository and session); never reach into the tag's views from the example.
- **Dependency:** the Example app only (a Podfile or a project-level package reference); never in this library's `podspec` or `Package.swift`. CollectionViewClassifyMenu reaches this library through CYLTabBarController, so the Example must resolve exactly one copy of this library (the one in this repository, `:path`).
- **Scope:** lists that exist to test scrolling (the fling rows of the Android, Flutter, React Native, HarmonyOS and Mini Program examples) stay as they are.
