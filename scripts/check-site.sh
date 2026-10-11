#!/bin/sh
# Static checks on a built site directory. The CI gate before any deploy.
#
#     sh scripts/check-site.sh build/release/site
#
# Fails on: a page without <title>, a local href/src pointing at a file that is
# not in the release, or pages disagreeing on the style.css?v= cache-buster.

set -eu

SITE="${1:?usage: check-site.sh <site-dir>}"
[ -d "$SITE" ] || { echo "Not a directory: $SITE"; exit 1; }
cd "$SITE"

errors=0
fail() { echo "  FAIL: $*"; errors=$((errors + 1)); }

echo "-> Checking pages in $SITE"
for page in *.html; do
  grep -q '<title>' "$page" || fail "$page has no <title>"

  for ref in $(grep -oE '(href|src)="[^"]*"' "$page" | sed -E 's/^(href|src)="//; s/"$//'); do
    case "$ref" in
      http:*|https:*|mailto:*|tel:*|data:*|javascript:*|//*|'#'*|'') continue ;;
    esac
    path=${ref%%#*}
    path=${path%%\?*}
    path=${path#/}
    [ -n "$path" ] || path=index.html
    case "$path" in */) path="${path}index.html" ;; esac
    [ -e "$path" ] || fail "$page links to missing file: $ref"
  done
done

# Cloudflare caches style.css for hours; every page must request the same ?v=
versions=$(grep -ohE 'style\.css\?v=[0-9]+' *.html | sort -u)
nversions=$(printf '%s\n' "$versions" | grep -c . || true)
if [ "$nversions" -gt 1 ]; then
  fail "pages use different stylesheet versions: $(echo $versions)"
fi

if [ "$errors" -gt 0 ]; then
  echo "Site check failed with $errors error(s)"
  exit 1
fi
echo "Site check passed ($(ls *.html | wc -l | tr -d ' ') pages, ${versions:-no versioned stylesheet})"
