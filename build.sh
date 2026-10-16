#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
DOTS_OUT="${1:-../Dots.app}"
mkdir -p "$DOTS_OUT/Contents/MacOS" "$DOTS_OUT/Contents/Resources" .build/module-cache
swiftc -O -swift-version 5 -target arm64-apple-macos13.0 -module-cache-path .build/module-cache Sources/*.swift -o "$DOTS_OUT/Contents/MacOS/Dots" -framework AppKit -framework ApplicationServices -framework ImageIO
cp Resources/spritesheet.webp Resources/animations.json "$DOTS_OUT/Contents/Resources/"
if [ -f Resources/Dots.icns ]; then cp Resources/Dots.icns "$DOTS_OUT/Contents/Resources/"; fi
cp Info.plist "$DOTS_OUT/Contents/Info.plist"
codesign --force --sign - --identifier studio.dots.usagi "$DOTS_OUT"
"$DOTS_OUT/Contents/MacOS/Dots" --self-test
