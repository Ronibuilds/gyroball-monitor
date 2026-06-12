#!/usr/bin/env bash
set -euo pipefail

# Phase 1 install: sets up a venv and installs bleak for the BLE probe script.

VENV_DIR="$(dirname "$0")/.venv"

# ── Python check ────────────────────────────────────────────────────────────
PYTHON=$(command -v python3 || true)
if [[ -z "$PYTHON" ]]; then
  echo "✗ python3 not found. Install it via: brew install python"
  exit 1
fi

PY_VERSION=$("$PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJOR=$("$PYTHON" -c 'import sys; print(sys.version_info.major)')
PY_MINOR=$("$PYTHON" -c 'import sys; print(sys.version_info.minor)')

if (( PY_MAJOR < 3 || (PY_MAJOR == 3 && PY_MINOR < 10) )); then
  echo "✗ Python 3.10+ required (found $PY_VERSION). Upgrade via: brew install python"
  exit 1
fi
echo "✓ Python $PY_VERSION"

# ── Virtual environment ──────────────────────────────────────────────────────
if [[ ! -d "$VENV_DIR" ]]; then
  echo "→ Creating virtual environment at .venv …"
  "$PYTHON" -m venv "$VENV_DIR"
fi
echo "✓ venv at .venv"

PIP="$VENV_DIR/bin/pip"
PYTHON_VENV="$VENV_DIR/bin/python"

# ── Dependencies ─────────────────────────────────────────────────────────────
echo "→ Installing bleak …"
"$PIP" install --quiet --upgrade bleak
echo "✓ bleak $("$PYTHON_VENV" -c 'import bleak; print(bleak.__version__)')"

# ── Executable bit ───────────────────────────────────────────────────────────
chmod +x "$(dirname "$0")/discovery/scan_and_probe.py"
echo "✓ scan_and_probe.py marked executable"

# ── Bluetooth permission hint ─────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  macOS: grant Bluetooth access to Terminal (or iTerm2)"
echo "  System Settings → Privacy & Security → Bluetooth"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run the probe with:"
echo "  .venv/bin/python discovery/scan_and_probe.py"
echo "  .venv/bin/python discovery/scan_and_probe.py --filter NSD"
echo "  .venv/bin/python discovery/scan_and_probe.py --address AA:BB:CC:DD:EE:FF --listen-time 120"
