#!/bin/zsh
# Starts `pnpm dsh web` from the checkout recorded in DSH_REPO_ROOT.
# Finder-launched apps have a minimal PATH, so Node is resolved via nvm.

REPO="${DSH_REPO_ROOT:?DSH_REPO_ROOT is required}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  # nvm.sh is not safe under `set -e`.
  . "$NVM_DIR/nvm.sh"
  nvm use 22 >/dev/null
fi

if ! command -v node >/dev/null 2>&1; then
  latest="$(ls -d "$HOME/.nvm/versions/node"/v22* 2>/dev/null | sort -V | tail -1)"
  if [ -n "$latest" ]; then
    export PATH="$latest/bin:$PATH"
  fi
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "ERROR: 找不到 pnpm。请先运行: corepack enable && corepack prepare pnpm@11.7.0 --activate" >&2
  exit 1
fi

cd "$REPO" || exit 1

if [ ! -d node_modules ]; then
  echo "ERROR: 缺少 node_modules。请在仓库根目录运行: pnpm install" >&2
  exit 1
fi

exec pnpm dsh web
