#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
DOTS_OUT="${1:-./dist/Dots.app}"
DOTS_CACHE_KEY="$(printf '%s' "$PWD" | shasum -a 256 | cut -c1-12)"
DOTS_CACHE=".build/module-cache-$DOTS_CACHE_KEY"
mkdir -p "$DOTS_OUT/Contents/MacOS" "$DOTS_OUT/Contents/Resources" "$DOTS_CACHE"
swiftc -O -swift-version 5 -target arm64-apple-macos13.0 -module-cache-path "$DOTS_CACHE" Sources/*.swift -o "$DOTS_OUT/Contents/MacOS/Dots" -framework AppKit -framework ApplicationServices -framework ImageIO
cp Resources/spritesheet.webp Resources/animations.json "$DOTS_OUT/Contents/Resources/"
if [ -f Resources/Dots.icns ]; then cp Resources/Dots.icns "$DOTS_OUT/Contents/Resources/"; fi
cp Info.plist "$DOTS_OUT/Contents/Info.plist"
codesign --force --sign - --identifier studio.dots.usagi "$DOTS_OUT"
"$DOTS_OUT/Contents/MacOS/Dots" --self-test
