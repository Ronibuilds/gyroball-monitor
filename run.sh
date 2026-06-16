#!/usr/bin/env bash
set -euo pipefail

echo "→ Building…"
swift build 2>&1

BINARY=".build/debug/gyroball"
APP=".build/Gyroball.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

echo "→ Bundling…"
mkdir -p "$MACOS" "$CONTENTS/Resources"
cp "$BINARY" "$MACOS/gyroball"
cp "gyroball/Info.plist" "$CONTENTS/Info.plist"
cp "assets/Gyroball.icns" "$CONTENTS/Resources/Gyroball.icns"

echo "→ Signing…"
codesign --force --sign - --entitlements "gyroball/gyroball.entitlements" "$APP"

echo "→ Launching…"
open "$APP"
