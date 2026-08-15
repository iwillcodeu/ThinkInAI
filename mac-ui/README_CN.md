# mac-ui

[English](README.md) | 中文

本地 Mac 启动器。点开 `ThinkInAI.app` 后，它会启动本仓库的 `dsh web`，并在独立窗口里打开 Web UI。若缺少 `node_modules` 或 Web 产物，会先执行 `nvm use 22`、`pnpm install`、`pnpm run build`。

`ThinkInAI.app` 和 `mac-ui/.build/` 是构建产物，不提交。

## 编译

### 一次性前置

本机需要：

- Node.js 22.19+（推荐 nvm：`nvm install 22 && nvm use 22`）
- 仓库锁定的 pnpm（`corepack enable && corepack prepare pnpm@11.7.0 --activate`）
- Xcode 或 Command Line Tools（提供 `swiftc`、`sips`、`iconutil`）

本机需要已安装 Node 22、仓库锁定的 pnpm，以及 Xcode 工具。缺少依赖或 Web 产物时，App 会自己执行 `pnpm install` 和 `pnpm run build`。JS/插件源码大改之后，在仓库根目录再构建一次（或删掉 `apps/web/dist` / `packages/client/connection/lib/client.js` 后重新打开 App）：

```sh
cd /path/to/ThinkInAI
nvm use 22
pnpm install
pnpm run build
```

### 编译 App

```sh
cd /path/to/ThinkInAI/mac-ui
./build.sh
```

成功时会打印 `Built .../mac-ui/ThinkInAI.app`。脚本会：

1. 用 `swiftc` 编译 `Sources/` 里的 SwiftUI + WKWebView 启动器
2. 把 `Assets/AppIcon.png`（ThinkInAI logo）打成 Dock 用的 `.icns`
3. 把当前仓库的绝对路径写入 App 包内的 `repo-root.txt`
4. 做本地 ad-hoc 签名

改了 `mac-ui/Sources/`、`Info.plist`、`launch-dsh-web.sh` 或图标后，重新执行 `./build.sh`。不必为此再跑 `pnpm run build`。

## 使用

### 打开

编译完成后任选一种方式：

```sh
open /path/to/ThinkInAI/mac-ui/ThinkInAI.app
```

或在访达中双击 `mac-ui/ThinkInAI.app`。也可以把该 App 拖到程序坞，之后只点图标。

首次若被拦截，按住 Control 点击图标，选「打开」。

不要只把 `.app` 拷到「应用程序」而丢掉这个 git checkout。App 通过包内的 `repo-root.txt` 找到仓库；拷走 App 会找不到 `pnpm dsh web`。需要换仓库路径时，在目标 checkout 里重新 `./build.sh`，或启动前设置 `DSH_REPO_ROOT`。

### 点开之后

1. App 检查 `http://127.0.0.1:3080`。若已经是本仓库的 Harness（首页带启动清单，且 connection 插件 JS 可取），就直接连上，退出时不停止该服务。
2. 否则用 nvm 的 Node 22 在仓库根目录准备环境：没有 `node_modules` 就执行 `pnpm install`，缺少 `apps/web/dist/index.html` 或 `packages/client/connection/lib/client.js` 就执行 `pnpm run build`，然后启动 `pnpm dsh web`。关掉 App 时一并停止该进程。
3. 窗口里就是 Web UI。第一次用：打开**设置 → 模型**，填入 DeepSeek API 密钥并保存；再点**选择工作区**，选一个项目目录。选中工作区前不能发消息。

窗口若一度出现 `Failed to load plugins`，App 会自动重载几次（服务刚起来时的竞态）。若一直失败，先看窗口里的启动日志，然后关掉 App 再打开。

### 日常要不要再编译

| 你改了什么 | 要做什么 |
|---|---|
| 只是用 agent、没改代码 | 直接点 App，不用编译 |
| 新 checkout，或缺少 `node_modules` / Web 产物 | 直接点 App；缺什么就自动跑 `pnpm install` / `pnpm run build` |
| `packages/`、`apps/web` 等仓库源码 | 在仓库根目录再跑 `pnpm run build`，然后点 App（App 本身不用重编） |
| `mac-ui/` 里的 Swift、图标、启动脚本 | 在 `mac-ui/` 再跑 `./build.sh`，然后点新的 App |

App 只在缺少这些产物时执行 `pnpm install` / `pnpm run build`，不会每次打开都跑。
