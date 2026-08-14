# mac-ui

English | [中文](README_CN.md)

A local Mac launcher. Opening `DeepSeekHarness.app` starts this checkout's already-built `dsh web` and shows the Web UI in its own window, so you do not compile or run from the command line every time.

`DeepSeekHarness.app` and `mac-ui/.build/` are build outputs and are not committed.

## Build

### One-time prerequisites

You need:

- Node.js 22.19+ (nvm recommended: `nvm install 22 && nvm use 22`)
- The repo-pinned pnpm (`corepack enable && corepack prepare pnpm@11.7.0 --activate`)
- Xcode or Command Line Tools (`swiftc`, `sips`, `iconutil`)

From the **repository root**, install dependencies and produce the Web artifacts. Do this once, and again after large JS or plugin source changes:

```sh
cd /path/to/deepseek-harness
nvm use 22
pnpm install
pnpm run build
```

### Build the app

```sh
cd /path/to/deepseek-harness/mac-ui
./build.sh
```

On success the script prints `Built .../mac-ui/DeepSeekHarness.app`. It:

1. Compiles the SwiftUI + WKWebView launcher in `Sources/` with `swiftc`
2. Turns `Assets/AppIcon.svg` (DeepSeek blue field, white whale) into a Dock `.icns`
3. Writes this checkout's absolute path into `repo-root.txt` inside the app bundle
4. Ad-hoc signs the app locally

Re-run `./build.sh` after changing `mac-ui/Sources/`, `Info.plist`, `launch-dsh-web.sh`, or the icon. You do not need `pnpm run build` for those edits.

## Use

### Open

After a successful build, either:

```sh
open /path/to/deepseek-harness/mac-ui/DeepSeekHarness.app
```

or double-click `mac-ui/DeepSeekHarness.app` in Finder. You can also drag the app to the Dock and click the icon after that.

If Gatekeeper blocks the first launch, Control-click the icon and choose Open.

Do not copy only the `.app` into `/Applications` and discard this git checkout. The app finds the repo through `repo-root.txt` in the bundle; a copied app cannot run `pnpm dsh web`. To point at another checkout, run `./build.sh` there, or set `DSH_REPO_ROOT` before launch.

### After it opens

1. The app checks `http://127.0.0.1:3080`. If that is already this checkout's Harness (index has the boot manifest, and the connection plugin JS is reachable), it attaches and does not stop that server on quit.
2. Otherwise it runs `pnpm dsh web` from the repo root with nvm Node 22, and stops that process when you quit the app.
3. The window is the Web UI. First use: open **Settings → Models**, enter a DeepSeek API key and save; then **Choose workspace** and select a project directory. The session input stays disabled until a workspace is selected.

If the window briefly shows `Failed to load plugins`, the app reloads a few times (a race while the server is coming up). If it keeps failing, confirm `pnpm install` and `pnpm run build` succeeded at the repo root, then quit and reopen the app.

### When you need to rebuild

| What changed | What to run |
|---|---|
| Using the agent only; no code changes | Click the app; no rebuild |
| Repo source such as `packages/` or `apps/web` | `pnpm run build` at the repo root, then click the app (do not rebuild the app) |
| Swift, icon, or launch scripts under `mac-ui/` | `./build.sh` in `mac-ui/`, then open the new app |

The app does **not** run `pnpm run build` on each launch.
