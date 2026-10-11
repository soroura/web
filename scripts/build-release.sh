#!/bin/sh
# Assemble a release in build/release/:
#   site/        exactly what nginx serves (plus version.txt = commit SHA)
#   deploy.sh    nginx.conf    scripts/
#
#     sh scripts/build-release.sh
#
# Runs in CI and locally. The output directory is fully rebuilt every time, so
# a file deleted from the repo is also gone from the next release.

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
OUT="$ROOT/build/release"
. "$ROOT/scripts/release-manifest.sh"

cd "$ROOT"

for f in $REQUIRED_FILES; do
  [ -f "$f" ] || { echo "Required site file missing: $f"; exit 1; }
done

rm -rf "$OUT"
mkdir -p "$OUT/site" "$OUT/scripts"

count=0
for f in $SITE_FILES; do
  # An unmatched glob stays literal; skip it.
  [ -f "$f" ] || continue
  cp "$f" "$OUT/site/$f"
  count=$((count + 1))
done

# Which commit is live: https://soroura.org/version.txt
if [ -n "${CI_COMMIT_SHA:-}" ]; then
  version="$CI_COMMIT_SHA"
else
  version=$(git rev-parse HEAD 2>/dev/null || echo unknown)
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    version="$version-dirty"
  fi
fi
printf '%s\n' "$version" > "$OUT/site/version.txt"

cp deploy.sh nginx.conf "$OUT/"
cp scripts/*.sh "$OUT/scripts/"
chmod +x "$OUT/deploy.sh" "$OUT"/scripts/*.sh

echo "Built release $version: $count site files in $OUT/site"
