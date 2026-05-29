#!/bin/bash
# Builds Resources/AppIcon.icns from the 1024px master. Regenerate after editing
# tools/make_app_icon.swift:
#   swiftc -O -framework AppKit -o build/mkicon tools/make_app_icon.swift && ./build/mkicon
#   ./tools/make_icns.sh
set -euo pipefail
cd "$(dirname "$0")/.."

MASTER="build/AppIcon-1024.png"
ICONSET="build/AppIcon.iconset"
[[ -f "$MASTER" ]] || { echo "missing $MASTER — run the icon generator first"; exit 1; }

rm -rf "$ICONSET"; mkdir -p "$ICONSET"
gen() { sips -z "$1" "$1" "$MASTER" --out "$ICONSET/$2" >/dev/null; }
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -rf "$ICONSET"
echo "wrote Resources/AppIcon.icns"
