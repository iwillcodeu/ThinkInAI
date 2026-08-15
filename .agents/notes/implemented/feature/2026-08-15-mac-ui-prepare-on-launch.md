# Agent Note: mac-ui prepares the checkout on launch

Status: implemented

English | [中文](2026-08-15-mac-ui-prepare-on-launch.zh.md)

## Problem

`ThinkInAI.app` only launched `pnpm dsh web`. A checkout without `node_modules` or Web artifacts opened a window that could not load the UI, and the failure text told the user to run `pnpm install` and `pnpm run build` by hand.

## Decision

`mac-ui/launch-dsh-web.sh` still selects nvm Node 22, then runs `pnpm install` when `node_modules` is missing and `pnpm run build` when `apps/web/dist/index.html` or `packages/client/connection/lib/client.js` is missing. If `pnpm` is absent after Node 22 is on `PATH`, the script runs `corepack enable` and `corepack prepare pnpm@11.7.0 --activate` before those steps. It then `exec`s `pnpm dsh web`.

The app does not rebuild on every launch. Source edits under `packages/` or `apps/web` still need an explicit `pnpm run build` (or deletion of those two artifacts) before the next open.

`ServerManager` waits up to 45 minutes for the owned process to become the Harness on `127.0.0.1:3080`, because a first `pnpm install` plus `pnpm run build` exceeds the previous 60-second ready wait. The starting pane publishes the process log and names the current step from that log. The process still fails immediately if the child exits.

## Alternatives considered

**Always run `pnpm install` and `pnpm run build` on every open.** Rejected because a full workspace build is minutes long and the launcher exists so daily use does not compile from the command line.

**Keep the 60-second ready wait and only print a better error.** Rejected because the first prepare cannot finish in 60 seconds, so the window would still fail after the script had started real work.

**Detect stale artifacts by comparing source mtimes.** Rejected because a cheap, reliable stamp across `tsc`, tsdown, and the Vite dist is not owned by this launcher; missing-file checks match the failure the app already probes (`apps/web/dist` and the connection `lib/client.js`).

## Consequences

Opening the app on a fresh checkout can take several minutes while install and build run; the window shows that log instead of a dead WebView. Later opens skip those steps when the artifacts exist. A hung child can occupy the starting pane for up to 45 minutes before the timeout text appears.
