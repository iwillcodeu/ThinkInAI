#!/bin/zsh
# Starts `pnpm dsh web` from the checkout recorded in DSH_REPO_ROOT.
# Finder-launched apps have a minimal PATH, so Node is resolved via nvm.
# Missing node_modules or Web artifacts trigger `pnpm install` / `pnpm run build`.

REPO="${DSH_REPO_ROOT:?DSH_REPO_ROOT is required}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

echo "正在准备 Node 22…"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # nvm.sh is not safe under `set -e`.
  . "$NVM_DIR/nvm.sh"
  nvm use 22
fi

if ! command -v node >/dev/null 2>&1; then
  latest="$(ls -d "$HOME/.nvm/versions/node"/v22* 2>/dev/null | sort -V | tail -1)"
  if [ -n "$latest" ]; then
    export PATH="$latest/bin:$PATH"
  fi
fi

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 找不到 Node 22。请先运行: nvm install 22 && nvm use 22" >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  if command -v corepack >/dev/null 2>&1; then
    echo "正在启用 pnpm（corepack prepare pnpm@11.7.0）…"
    corepack enable
    corepack prepare pnpm@11.7.0 --activate
  fi
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "ERROR: 找不到 pnpm。请先运行: corepack enable && corepack prepare pnpm@11.7.0 --activate" >&2
  exit 1
fi

echo "Node $(node -v)，pnpm $(pnpm -v)"

cd "$REPO" || exit 1

if [ ! -d node_modules ]; then
  echo "正在执行 pnpm install…"
  pnpm install || exit 1
fi

if [ ! -f apps/web/dist/index.html ] || [ ! -f packages/client/connection/lib/client.js ]; then
  echo "正在执行 pnpm run build…"
  pnpm run build || exit 1
fi

echo "正在启动 pnpm dsh web…"
exec pnpm dsh web
