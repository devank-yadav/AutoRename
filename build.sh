#!/bin/bash
# Builds the AutoRename menu bar app bundle without Xcode, using swiftc + the
# Command Line Tools macOS SDK. Produces ./build/AutoRename.app.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="AutoRename"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RES_DIR="$APP_BUNDLE/Contents/Resources"

echo "==> Cleaning"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "==> Compiling Swift sources (universal: arm64 + x86_64)"
SOURCES=$(find Sources -name '*.swift')
FRAMEWORKS=(-framework AppKit -framework SwiftUI -framework Vision -framework PDFKit
            -framework AVFoundation -framework Speech -framework UniformTypeIdentifiers
            -framework Security)

compile_arch() {
    local arch="$1" out="$2"
    swiftc -O -target "${arch}-apple-macos13.0" "${FRAMEWORKS[@]}" -o "$out" $SOURCES
}

compile_arch arm64  "$BUILD_DIR/$APP_NAME-arm64"
compile_arch x86_64 "$BUILD_DIR/$APP_NAME-x86_64"

echo "==> Creating universal binary with lipo"
lipo -create -output "$MACOS_DIR/$APP_NAME" \
    "$BUILD_DIR/$APP_NAME-arm64" "$BUILD_DIR/$APP_NAME-x86_64"
rm -f "$BUILD_DIR/$APP_NAME-arm64" "$BUILD_DIR/$APP_NAME-x86_64"

echo "==> Assembling bundle"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"

# Optional: embed an API key so the app works without the user supplying one.
# Resources/embedded-key.txt is git-ignored; present it only if you intend to
# ship your own key inside the app.
if [[ -f Resources/embedded-key.txt ]]; then
    cp Resources/embedded-key.txt "$RES_DIR/embedded-key.txt"
    echo "    embedded API key included in bundle"
fi

echo "==> Ad-hoc codesigning (needed for TCC permission prompts)"
codesign --force --deep \
    --sign - \
    --entitlements Resources/AutoRename.entitlements \
    "$APP_BUNDLE" 2>/dev/null || echo "    (codesign skipped/failed — app still runnable)"

echo "==> Done: $APP_BUNDLE"
