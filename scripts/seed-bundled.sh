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
  echo "Seeding $BUNDLE …"
  TMP="$(mktemp)"
  # --seed writes JSON to stdout, status messages and errors to stderr.
  # Exit codes: 0=success, 2=usage, 3=app-not-running, 4=encode-fail, 5=backend-fail.
  if "$BIN" --seed "$BUNDLE" > "$TMP" 2>&1 >"$TMP" && [ -s "$TMP" ]; then
    if [ "$FIRST" -eq 0 ]; then echo "," >> "$OUT"; fi
    cat "$TMP" >> "$OUT"
    FIRST=0
    echo "  ok ($(wc -c < "$TMP") bytes)"
  else
    RC=$?
    echo "  failed (exit $RC) — running with stderr visible to diagnose:"
    "$BIN" --seed "$BUNDLE" >/dev/null || true
  fi
  rm -f "$TMP"
done

echo "" >> "$OUT"
echo "]" >> "$OUT"
echo "Wrote $OUT"
