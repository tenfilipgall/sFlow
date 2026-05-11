#!/usr/bin/env bash
# scripts/seed-bundled.sh
# Build SFlow, then call --seed for each of the 4 verified apps.
# Each target app MUST be running before this script runs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="/tmp/sflow-seed-build"

APPS=(
  "com.tinyspeck.slackmacgap"
  "com.apple.Terminal"
  "notion.id"
  "com.anthropic.claudefordesktop"
)

echo "Building SFlow (debug)…"
xcodebuild build \
  -scheme SFlow -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' >/dev/null

BIN="$BUILD_DIR/Build/Products/Debug/SFlow.app/Contents/MacOS/SFlow"
if [ ! -x "$BIN" ]; then
  echo "error: SFlow binary not found at $BIN" >&2
  exit 1
fi

OUT="$ROOT/SFlow/Resources/bundled.json"
mkdir -p "$(dirname "$OUT")"
echo "[" > "$OUT"

FIRST=1
for BUNDLE in "${APPS[@]}"; do
  if ! pgrep -lf "$BUNDLE" >/dev/null 2>&1; then
    if ! osascript -e "exists application id \"$BUNDLE\"" >/dev/null 2>&1; then
      echo "skip $BUNDLE (not installed)"
      continue
    fi
    echo "warning: $BUNDLE is not currently running; AX dump will be empty"
  fi
  echo "Seeding $BUNDLE …"
  TMP="$(mktemp)"
  if "$BIN" --seed "$BUNDLE" > "$TMP" 2>/dev/null; then
    if [ "$FIRST" -eq 0 ]; then echo "," >> "$OUT"; fi
    cat "$TMP" >> "$OUT"
    FIRST=0
  else
    echo "  failed (see error output)"
  fi
  rm -f "$TMP"
done

echo "" >> "$OUT"
echo "]" >> "$OUT"
echo "Wrote $OUT"
