#!/usr/bin/env bash
# Builds a release Gyroball.app, packages it as a drag-to-Applications DMG,
# and installs it to /Applications.
set -euo pipefail

APP_NAME="Gyroball"
DIST="dist"
APP="$DIST/$APP_NAME.app"

# Universal (arm64 + x86_64) builds need full Xcode; with just the Command
# Line Tools we build for the native architecture only.
echo "→ Building release…"
swift build -c release
BINARY=".build/release/gyroball"

echo "→ Bundling…"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/gyroball"
cp gyroball/Info.plist "$APP/Contents/Info.plist"
cp assets/Gyroball.icns "$APP/Contents/Resources/Gyroball.icns"

echo "→ Signing…"
codesign --force --sign - --entitlements gyroball/gyroball.entitlements "$APP"

echo "→ Creating DMG…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -quiet \
    -format UDZO "$DIST/$APP_NAME.dmg"
rm -rf "$STAGE"

echo "→ Installing to /Applications…"
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP" "/Applications/$APP_NAME.app"

echo
echo "✓ Installed:  /Applications/$APP_NAME.app"
echo "✓ Shareable:  $DIST/$APP_NAME.dmg"
