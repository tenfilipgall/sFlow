#!/usr/bin/env bash
# Build a distributable DMG for beta-testers.
#
# Usage:
#   ./scripts/build-dmg.sh                    # uses today's date as version
#   ./scripts/build-dmg.sh v0.2               # explicit tag
#
# Output:
#   SFlow-<version>.dmg in repo root (gitignored)
#
# Requires:
#   - Xcode CLI tools
#   - macOS hdiutil (built-in)
#
# Notes:
#   - Builds Release configuration (smaller binary, optimized).
#   - Uses ad-hoc signing (CODE_SIGN_IDENTITY="-") so the DMG works for
#     Filip + close-network beta-testers. macOS will show "developer
#     unidentified" on first launch; tester right-clicks → Open the first
#     time to bypass. For wider distribution later, switch to a proper
#     Developer ID signed + notarized build.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(date +v0.1-%Y%m%d)}"
DMG_NAME="SFlow-${VERSION}.dmg"
STAGE_DIR="/tmp/sflow-dmg-stage-$$"
DERIVED_DIR="$HOME/Library/Developer/Xcode/DerivedData"

echo "==> Building SFlow Release configuration"
xcodebuild -project SFlow.xcodeproj \
    -scheme SFlow \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath build/dmg \
    clean build \
    2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -20

APP_PATH="build/dmg/Build/Products/Release/SFlow.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "✗ Build failed — SFlow.app not found at $APP_PATH" >&2
    exit 1
fi

echo "==> Staging DMG contents"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/SFlow.app"
ln -s /Applications "$STAGE_DIR/Applications"

echo "==> Creating DMG"
rm -f "$DMG_NAME"
hdiutil create \
    -volname "SFlow ${VERSION}" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME" \
    > /dev/null

rm -rf "$STAGE_DIR"

DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
echo ""
echo "✓ DMG built: $DMG_NAME ($DMG_SIZE)"
echo ""
echo "Distribution checklist for beta-testers:"
echo "  1. Tester downloads $DMG_NAME"
echo "  2. Tester opens DMG, drags SFlow.app → /Applications"
echo "  3. First launch: right-click → Open (bypasses Gatekeeper unidentified-dev warning)"
echo "  4. macOS prompts for Accessibility + Input Monitoring → tester clicks 'Open System Settings'"
echo "  5. Tester enables both toggles → restarts SFlow"
echo "  6. silentMode default ON → tester uses Mac normally for 2-3 days"
echo "  7. Settings → Advanced → Export diagnostic bundle → DM zip to Filip"
echo ""
echo "If sending UPDATE to an existing tester (v0.1 → v0.2):"
echo "  - Tester drags new SFlow.app → /Applications, replaces old"
echo "  - User data (events.jsonl, preferences, permissions) preserved automatically"
echo "  - bundled.json upgraded automatically via P-19 fingerprint comparison"
