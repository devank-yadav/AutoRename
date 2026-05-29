#!/bin/bash
# Packages AutoRename.app into a downloadable .dmg (drag-to-Applications).
#
# Tiers:
#   1. Default (no credentials): builds an ad-hoc-signed DMG. Works, but macOS
#      Gatekeeper will warn users; they must right-click → Open the first time.
#   2. Notarized (set the env vars below): signs with a Developer ID cert and
#      notarizes with Apple so the app opens with no warning. Needs a paid
#      Apple Developer account.
#
# Optional env vars for Tier 2:
#   DEV_ID_APP   e.g. "Developer ID Application: Your Name (TEAMID)"
#   AC_PROFILE   name of a stored notarytool keychain profile
#                (create once: xcrun notarytool store-credentials AC_PROFILE \
#                   --apple-id you@example.com --team-id TEAMID --password app-specific-pw)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="AutoRename"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_STAGE="$BUILD_DIR/dmg"
DMG_OUT="$BUILD_DIR/$APP_NAME.dmg"

echo "==> Building app"
./build.sh >/dev/null
echo "    built $APP_BUNDLE"

# Tier 2: real Developer ID signing (overrides the ad-hoc signature).
if [[ -n "${DEV_ID_APP:-}" ]]; then
    echo "==> Signing with Developer ID: $DEV_ID_APP"
    codesign --force --deep --options runtime --timestamp \
        --entitlements Resources/AutoRename.entitlements \
        --sign "$DEV_ID_APP" "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

echo "==> Staging DMG contents"
rm -rf "$DMG_STAGE" "$DMG_OUT"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

# Ship install help only for the unsigned tier (notarized apps open cleanly).
if [[ -z "${DEV_ID_APP:-}" ]]; then
    cat > "$DMG_STAGE/HOW TO INSTALL.txt" <<'TXT'
AutoRename — Installation
=========================

1. Drag AutoRename.app onto the Applications folder (shown here).

2. First launch — macOS will warn that the app is from an
   unidentified developer. To open it:

   • Open Applications, RIGHT-CLICK AutoRename, choose "Open",
     then click "Open" in the dialog.

   • If macOS still blocks it (newer versions do), go to:
     System Settings → Privacy & Security → scroll down →
     click "Open Anyway" next to AutoRename.

   • Or, in Terminal, run:
       xattr -dr com.apple.quarantine /Applications/AutoRename.app
     then open the app normally.

   You only need to do this once.

3. AutoRename lives in your menu bar (the wand icon). It works out of
   the box — no API key or sign-up needed.

4. To rename: select files in Finder, click the menu bar icon →
   "Rename Finder Selection". Review the suggested names, then Apply.
   The first run will ask permission to read your Finder selection.
TXT
fi

# Bundle the window background image (hidden folder Finder reads).
if [[ -f Resources/dmg-background.png ]]; then
    mkdir -p "$DMG_STAGE/.background"
    cp Resources/dmg-background.png "$DMG_STAGE/.background/background.png"
fi

RW_DMG="$BUILD_DIR/$APP_NAME-rw.dmg"
VOL="/Volumes/$APP_NAME"

echo "==> Creating writable DMG"
rm -f "$RW_DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE" \
    -fs HFS+ -format UDRW \
    "$RW_DMG" >/dev/null
rm -rf "$DMG_STAGE"

echo "==> Applying Finder window layout"
hdiutil detach "$VOL" >/dev/null 2>&1 || true
hdiutil attach "$RW_DMG" -nobrowse >/dev/null
osascript <<OSA 2>/dev/null || echo "    (Finder layout skipped — grant Automation permission to polish next time)"
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 150, 1060, 550}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {165, 195}
        set position of item "Applications" of container window to {495, 195}
        try
            set position of item "HOW TO INSTALL.txt" of container window to {330, 330}
        end try
        update without registering applications
        delay 1
        close
    end tell
end tell
OSA
sync
hdiutil detach "$VOL" >/dev/null 2>&1 || true

echo "==> Converting to compressed DMG"
rm -f "$DMG_OUT"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" >/dev/null
rm -f "$RW_DMG"

# Tier 2: notarize + staple so Gatekeeper trusts the download.
if [[ -n "${DEV_ID_APP:-}" && -n "${AC_PROFILE:-}" ]]; then
    echo "==> Notarizing (this can take a few minutes)"
    xcrun notarytool submit "$DMG_OUT" --keychain-profile "$AC_PROFILE" --wait
    echo "==> Stapling ticket"
    xcrun stapler staple "$DMG_OUT"
    xcrun stapler validate "$DMG_OUT"
fi

echo
echo "==> Done: $DMG_OUT"
echo "    $(du -h "$DMG_OUT" | cut -f1) — $(lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || echo 'binary')"
if [[ -z "${DEV_ID_APP:-}" ]]; then
    echo
    echo "    NOTE: unsigned/ad-hoc build. Users must right-click the app → Open"
    echo "    on first launch, or run: xattr -dr com.apple.quarantine /Applications/$APP_NAME.app"
fi
