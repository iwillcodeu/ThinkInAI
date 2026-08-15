# Agent Note: mac-ui 打开时准备仓库

Status: implemented

[English](2026-08-15-mac-ui-prepare-on-launch.md) | 中文

## 问题

`ThinkInAI.app` 原先只启动 `pnpm dsh web`。缺少 `node_modules` 或 Web 产物的 checkout 打开后窗口无法加载 UI，失败文案只是让用户自己去跑 `pnpm install` 和 `pnpm run build`。

## 决策

`mac-ui/launch-dsh-web.sh` 仍会选中 nvm 的 Node 22；若没有 `node_modules` 就执行 `pnpm install`，若缺少 `apps/web/dist/index.html` 或 `packages/client/connection/lib/client.js` 就执行 `pnpm run build`。Node 22 已在 `PATH` 上但仍找不到 `pnpm` 时，脚本先执行 `corepack enable` 和 `corepack prepare pnpm@11.7.0 --activate`。然后 `exec` `pnpm dsh web`。

App 不会在每次打开时重新构建。改了 `packages/` 或 `apps/web` 的源码后，仍需显式执行 `pnpm run build`（或删掉上述两个产物）再打开。

`ServerManager` 最多等待 45 分钟，直到自有进程成为 `127.0.0.1:3080` 上的 Harness，因为首次 `pnpm install` 加 `pnpm run build` 会超过原先 60 秒的就绪等待。启动页会发布进程日志，并根据日志标出当前步骤。子进程退出时仍立即失败。

## 备选方案

**每次打开都跑 `pnpm install` 和 `pnpm run build`。** 否决，因为完整工作区构建要数分钟，而启动器的目的就是日常使用不必在命令行编译。

**保留 60 秒就绪等待，只把错误写得更清楚。** 否决，因为首次准备不可能在 60 秒内结束，脚本已经开始干活时窗口仍会失败。

**用源文件 mtime 判断产物过期。** 否决，因为跨 `tsc`、tsdown 和 Vite dist 的廉价可靠戳记不属于这个启动器；缺文件检查与 App 已有的探测（`apps/web/dist` 与 connection 的 `lib/client.js`）一致。

## 后果

在全新 checkout 上打开 App 可能要花几分钟做安装和构建；窗口会显示这段日志，而不是一张死掉的 WebView。之后只要产物还在，打开就会跳过这些步骤。子进程挂死时，启动页最多占满 45 分钟才出现超时文案。
