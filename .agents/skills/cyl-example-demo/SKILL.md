---
name: cyl-example-demo
description: "How a demo example of CYLDeallocBlockExecutor shows a table-view style with sections: replace it with CollectionViewClassifyMenu's tag list (section headers with titles, More/Less fold with built-in icon, tap = old cell action, long-press subtitle popover with an arrow, wrapping titles, adaptive width, 3 rows max). Use before adding or changing a grouped list in any example."
---

# Example demo: sectioned lists (added 2026-11-25)

The same rule is in `instructions.md` ("Example demo: sectioned lists use the ClassifyMenu tag list"). When they disagree, `instructions.md` wins; fix this file.

## Checklist

1. Does the screen need sections (grouped rows)? If not, stop; this rule does not apply. Scroll-test lists of the Android, Flutter, React Native, HarmonyOS and Mini Program examples stay as they are.
2. Build one `CYLTagListView`: one tag per row (main title and icon), one section per group, a title on every section header.
3. Fold: `defaultVisibleRows = 3` (the example's maximum), the fold control shows "More" / "Less" with its built-in icon.
4. Tap: `tagClickHandler` runs the old `didSelectRowAt` action.
5. Long press: `tagLongPressHandler` shows the subtitle in a small popover with an arrow; return `.none` from `adaptivePresentationStyle(for:)` so it stays a popover on iPhone.
6. Wrap: `style.titleWraps = true`; tag width adaptive, so a row holds as many tags as fit.
7. Missing API: add it to CollectionViewClassifyMenu first (its own repository and session); never reach into tag views from the example.
8. Dependency: Example app only; one copy of this library (`:path`); never add the menu to this library's `podspec` or `Package.swift`.
9. Verify on one simulator of your own: tap, long-press popover, fold with More / Less, a wrapped title; labeled original-pixel screenshots.
