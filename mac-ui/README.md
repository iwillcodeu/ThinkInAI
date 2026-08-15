# mac-ui

English | [中文](README_CN.md)

A local Mac launcher. Opening `ThinkInAI.app` starts this checkout's `dsh web` and shows the Web UI in its own window. If `node_modules` or the Web artifacts are missing, the app runs `nvm use 22`, `pnpm install`, and `pnpm run build` first.

`ThinkInAI.app` and `mac-ui/.build/` are build outputs and are not committed.

## Build

### One-time prerequisites

You need:

- Node.js 22.19+ (nvm recommended: `nvm install 22 && nvm use 22`)
- The repo-pinned pnpm (`corepack enable && corepack prepare pnpm@11.7.0 --activate`)
- Xcode or Command Line Tools (`swiftc`, `sips`, `iconutil`)

Node 22, the repo-pinned pnpm, and Xcode tools must already be on the machine. The app itself runs `pnpm install` and `pnpm run build` when those artifacts are missing. After large JS or plugin source changes, rebuild at the repository root (or delete `apps/web/dist` / `packages/client/connection/lib/client.js` and reopen the app):

```sh
cd /path/to/ThinkInAI
nvm use 22
pnpm install
pnpm run build
```

### Build the app

```sh
cd /path/to/ThinkInAI/mac-ui
./build.sh
```

On success the script prints `Built .../mac-ui/ThinkInAI.app`. It:

1. Compiles the SwiftUI + WKWebView launcher in `Sources/` with `swiftc`
2. Turns `Assets/AppIcon.png` (ThinkInAI logo) into a Dock `.icns`
3. Writes this checkout's absolute path into `repo-root.txt` inside the app bundle
4. Ad-hoc signs the app locally

Re-run `./build.sh` after changing `mac-ui/Sources/`, `Info.plist`, `launch-dsh-web.sh`, or the icon. You do not need `pnpm run build` for those edits.

## Use

### Open

After a successful build, either:

```sh
open /path/to/ThinkInAI/mac-ui/ThinkInAI.app
```

or double-click `mac-ui/ThinkInAI.app` in Finder. You can also drag the app to the Dock and click the icon after that.

If Gatekeeper blocks the first launch, Control-click the icon and choose Open.

Do not copy only the `.app` into `/Applications` and discard this git checkout. The app finds the repo through `repo-root.txt` in the bundle; a copied app cannot run `pnpm dsh web`. To point at another checkout, run `./build.sh` there, or set `DSH_REPO_ROOT` before launch.

### After it opens

1. The app checks `http://127.0.0.1:3080`. If that is already this checkout's Harness (index has the boot manifest, and the connection plugin JS is reachable), it attaches and does not stop that server on quit.
2. Otherwise it uses nvm Node 22 in the repo root: `pnpm install` if `node_modules` is missing, `pnpm run build` if `apps/web/dist/index.html` or `packages/client/connection/lib/client.js` is missing, then `pnpm dsh web`. Quitting the app stops that process.
3. The window is the Web UI. First use: open **Settings → Models**, enter a DeepSeek API key and save; then **Choose workspace** and select a project directory. The session input stays disabled until a workspace is selected.

If the window briefly shows `Failed to load plugins`, the app reloads a few times (a race while the server is coming up). If it keeps failing, read the startup log in the window, then quit and reopen the app.

### When you need to rebuild

| What changed | What to run |
|---|---|
| Using the agent only; no code changes | Click the app; no rebuild |
| Fresh checkout, or missing `node_modules` / Web artifacts | Click the app; it runs `pnpm install` and `pnpm run build` as needed |
| Repo source such as `packages/` or `apps/web` | `pnpm run build` at the repo root, then click the app (do not rebuild the app) |
| Swift, icon, or launch scripts under `mac-ui/` | `./build.sh` in `mac-ui/`, then open the new app |

The app runs `pnpm install` / `pnpm run build` only when those artifacts are missing, not on every launch.
