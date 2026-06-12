#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodegen &>/dev/null; then
    echo "→ Installing xcodegen…"
    brew install xcodegen
fi

echo "→ Generating gyroball.xcodeproj…"
xcodegen generate

echo "✓ Done. Run: open gyroball.xcodeproj"
