#!/usr/bin/env bash
# Merges per-app rule cache files (written by Reseeder) into the shipping bundled.json.
# Prints a git diff at the end for review. Does not commit.
set -euo pipefail

CACHE_DIR="$HOME/Library/Application Support/SFlow/rules/cache"
BUNDLED_PATH="SFlow/Resources/bundled.json"

if [[ ! -d "$CACHE_DIR" ]]; then
  echo "promote-to-bundled: no cache directory at $CACHE_DIR" >&2
  exit 1
fi

if ! command -v jq >/dev/null; then
  echo "promote-to-bundled: this script requires jq. Install with: brew install jq" >&2
  exit 1
fi

shopt -s nullglob
files=("$CACHE_DIR"/*.json)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "promote-to-bundled: no cache files to promote." >&2
  exit 1
fi

tmp=$(mktemp)
jq -s '.' "${files[@]}" > "$tmp"

mv "$tmp" "$BUNDLED_PATH"
echo "promote-to-bundled: wrote $BUNDLED_PATH from ${#files[@]} cache file(s)."
echo
echo "Diff (review before committing):"
git --no-pager diff -- "$BUNDLED_PATH" | head -120
