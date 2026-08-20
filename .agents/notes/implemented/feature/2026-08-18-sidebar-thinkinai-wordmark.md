# Agent Note: Sidebar ThinkInAI wordmark

Status: implemented

English | [中文](2026-08-18-sidebar-thinkinai-wordmark.zh.md)

## Problem

The expanded sidebar shows only the DeepSeek Harness wordmark. ThinkInAI needs its own mark under that bar, the same 182×24 canvas, and the same Appearance response so a light or dark preference cannot leave one mark unreadable.

## Decision

`ThinkInAIWordmark` is a package-internal SVG in `ui-sidebar`: a check-circle drawn from the product mark plus the ThinkInAI name, on a 182×24 viewBox. Fills and strokes use `currentColor`, so the mark inherits the sidebar's `--dsw-alias-label-primary` with the official slotted brand. There is no hardcoded palette and no neon glow, because a glow plate would only read in dark Appearance.

`SidebarRoot` keeps the official `sidebar.brand.mark` / `sidebar.brand.name` row and stacks the ThinkInAI bar under it in the existing brand New Session button. The expanded logo row grows with `min-height: 72px` and top-aligns the collapse toggle beside the official row. The collapsed rail still shows only the mark slot and the panel icon.

## Alternatives considered

**Reuse the raster `assets/ThinkInAI logo.png`.** Rejected because that file is a dark circular plate with a magenta glow. An `<img>` cannot follow Appearance the way `BrandWordmark` follows `currentColor`, and a pair of baked light/dark PNGs would drift from the token theme.

**Export the mark from `ui-primitives` beside `BrandWordmark`.** Rejected because that package is the shared DeepSeek atom set. A ThinkInAI-only glyph belongs with the sidebar shell that shows it; the `/client` export surface stays `apply` / `inject` plus contract types.

**Keep the 60px logo row and scale both marks down.** Rejected because the request is a second bar of the same width and height, not a shared compressed row.

## Consequences

Expanded sidebar chrome shows two 182×24 bars that recolor with Appearance. Snapshot coverage of `SidebarRoot` plus a wordmark unit test pin the canvas, `currentColor` ink, and the stacked brand button. Collapsed geometry is unchanged.
