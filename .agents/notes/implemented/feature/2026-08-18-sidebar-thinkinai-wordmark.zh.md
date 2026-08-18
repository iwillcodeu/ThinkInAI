# Agent Note: Sidebar ThinkInAI wordmark

Status: implemented

[English](2026-08-18-sidebar-thinkinai-wordmark.md) | 中文

## Problem

展开的侧栏只显示 DeepSeek Harness 字标。ThinkInAI 需要在该长条下方放自己的标识，画幅同为 182×24，并且对 Appearance 的响应必须一致，以免浅色或深色偏好让其中一个标识无法辨认。

## Decision

`ThinkInAIWordmark` 是 `ui-sidebar` 的包内 SVG：从产品标识抽出的圆圈对勾，加上 ThinkInAI 名称，画在 DeepSeek 字标的 182×24 viewBox 上。描边与填充使用 `currentColor`，因此它与 `BrandWordmark` 一样继承侧栏的 `--dsw-alias-label-primary`。没有写死的色板，也没有霓虹光晕，因为光晕底板只在深色 Appearance 下可读。

`SidebarRoot` 把两枚标识叠在现有的品牌 New Session 按钮里。展开时 logo 行增高到 72px，折叠按钮与 DeepSeek 字标顶对齐。折叠轨道仍然只显示鲸鱼标和面板图标。

## Alternatives considered

**复用栅格图 `assets/ThinkInAI logo.png`。** 否决，因为该文件是带品红光晕的深色圆形底板。`<img>` 无法像 `BrandWordmark` 跟随 `currentColor` 适配 Appearance，而再备一对浅色／深色 PNG 会与 token 主题脱节。

**把该标识从 `ui-primitives` 与 `BrandWordmark` 并列导出。** 否决，因为该包是共享的 DeepSeek 原子集。仅属于 ThinkInAI 的字形应放在展示它的侧栏外壳里；`/client` 导出面仍只含 `apply`／`inject` 与契约类型。

**保持 60px 的 logo 行并缩小两枚标识。** 否决，因为需求是第二条等宽等高的长条，而不是挤在同一行里。

## Consequences

展开的侧栏 chrome 显示两条 182×24 长条，并随 Appearance 一起改色。`SidebarRoot` 的快照覆盖加上字标单元测试钉住画幅、`currentColor` 油墨，以及叠放的品牌按钮。折叠几何不变。
