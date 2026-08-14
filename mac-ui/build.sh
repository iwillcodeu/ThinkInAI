#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
APP="$ROOT/DeepSeekHarness.app"
BIN="$APP/Contents/MacOS/DeepSeekHarness"
RESOURCES="$APP/Contents/Resources"
SDK="$(xcrun --show-sdk-path --sdk macosx)"
ARCH="$(uname -m)"

if [[ "$ARCH" == "arm64" ]]; then
  TARGET="arm64-apple-macosx14.0"
else
  TARGET="x86_64-apple-macosx14.0"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RESOURCES"

swiftc -parse-as-library -O -o "$BIN" \
  -target "$TARGET" \
  -sdk "$SDK" \
  -framework SwiftUI \
  -framework WebKit \
  -framework AppKit \
  "$ROOT/Sources/"*.swift

ICONSET="$ROOT/.build/AppIcon.iconset"
ICNS="$ROOT/.build/AppIcon.icns"
MASTER="$ROOT/.build/AppIcon-1024.png"
mkdir -p "$ICONSET"
swift "$ROOT/scripts/rasterize-svg.swift" "$ROOT/Assets/AppIcon.svg" "$MASTER" 1024
for spec in \
  "icon_16x16.png:16" \
  "icon_16x16@2x.png:32" \
  "icon_32x32.png:32" \
  "icon_32x32@2x.png:64" \
  "icon_128x128.png:128" \
  "icon_128x128@2x.png:256" \
  "icon_256x256.png:256" \
  "icon_256x256@2x.png:512" \
  "icon_512x512.png:512" \
  "icon_512x512@2x.png:1024"
do
  name="${spec%%:*}"
  px="${spec##*:}"
  sips -z "$px" "$px" "$MASTER" --out "$ICONSET/$name" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ICNS"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/launch-dsh-web.sh" "$RESOURCES/launch-dsh-web.sh"
cp "$ICNS" "$RESOURCES/AppIcon.icns"
chmod +x "$RESOURCES/launch-dsh-web.sh" "$BIN"
printf '%s\n' "$REPO" > "$RESOURCES/repo-root.txt"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --deep --sign - "$APP" >/dev/null

echo "Built $APP"
echo "Open with: open \"$APP\""
