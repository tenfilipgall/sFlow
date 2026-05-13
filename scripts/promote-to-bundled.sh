#!/usr/bin/env bash
# Merges per-app rule cache files (written by Reseeder) into the shipping bundled.json.
# Additive: existing bundleIds are REPLACED with cache versions; new bundleIds APPENDED.
# Prints a git diff at the end for review. Does not commit.
#
# Usage:
#   ./scripts/promote-to-bundled.sh                       # promote all cache files
#   ./scripts/promote-to-bundled.sh <bundleId> [...]      # promote only listed bundleIds
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
if [[ ! -f "$BUNDLED_PATH" ]]; then
  echo "promote-to-bundled: bundled.json not found at $BUNDLED_PATH" >&2
  exit 1
fi

shopt -s nullglob

# Build the file list — either user-specified bundleIds or all cache files
files=()
if [[ $# -gt 0 ]]; then
  for bid in "$@"; do
    f="$CACHE_DIR/$bid.json"
    if [[ -f "$f" ]]; then
      files+=("$f")
    else
      echo "promote-to-bundled: no cache for $bid (expected $f) — skipping" >&2
    fi
  done
else
  files=("$CACHE_DIR"/*.json)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "promote-to-bundled: no cache files to promote." >&2
  exit 1
fi

# Merge: read existing bundled.json as base, replace-or-append each cache entry by bundleId.
tmp=$(mktemp)
cp "$BUNDLED_PATH" "$tmp"

for f in "${files[@]}"; do
  bid=$(jq -r '.bundleId' "$f")
  if [[ -z "$bid" || "$bid" == "null" ]]; then
    echo "promote-to-bundled: skipping $f (no bundleId)" >&2
    continue
  fi
  out=$(mktemp)
  jq --slurpfile new "$f" --arg bid "$bid" '
    . as $base |
    if any(.[]; .bundleId == $bid)
      then map(if .bundleId == $bid then $new[0] else . end)
      else $base + [$new[0]]
    end
  ' "$tmp" > "$out"
  mv "$out" "$tmp"
done

mv "$tmp" "$BUNDLED_PATH"

count=${#files[@]}
echo "promote-to-bundled: merged $count cache file(s) into $BUNDLED_PATH."
echo
echo "Diff (review before committing):"
git --no-pager diff --stat -- "$BUNDLED_PATH"
echo
echo "Run 'git diff -- $BUNDLED_PATH' for the full diff."
