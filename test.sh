#!/usr/bin/env bash
# Smoke test, needs network, GNU tar, curl and jq. On macOS:
#   docker run --rm -v "$PWD":/bp -w /bp ubuntu:24.04 \
#     sh -c 'apt-get update -qq && apt-get install -qq -y curl jq >/dev/null && ./test.sh'
set -euo pipefail
cd "$(dirname "$0")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/build" "$tmp/cache"

echo "app-procfile" > "$tmp/build/Procfile"

# Pinned version, without the "v"
SITES_CONFORMES_VERSION=4.3.1 bin/compile "$tmp/build" "$tmp/cache"
grep -q '__version__ = "4.3.1"' "$tmp/build/sites_conformes/_version.py"
test -f "$tmp/build/manage.py" -a -f "$tmp/build/uv.lock" -a -f "$tmp/build/Aptfile"
grep -qx "app-procfile" "$tmp/build/Procfile" # app repo files are not overwritten

# Second build: served from the cache, other versions are evicted
touch "$tmp/cache/sites-conformes-v0.0.1.tar.gz"
SITES_CONFORMES_VERSION=v4.3.1 bin/compile "$tmp/build" "$tmp/cache" | grep "Using cached" >/dev/null
test ! -e "$tmp/cache/sites-conformes-v0.0.1.tar.gz"

# Unknown version fails the build (`! cmd` would not trip set -e)
if SITES_CONFORMES_VERSION=0.0.0 bin/compile "$tmp/build" "$tmp/cache" 2>/dev/null; then
  echo "FAIL: unknown version did not fail" >&2
  exit 1
fi

# latest resolves to a real release, never a pre-release
rm -rf "$tmp/build" && mkdir "$tmp/build"
bin/compile "$tmp/build" "$tmp/cache" | grep -E "Sites Conformes v[0-9]+\.[0-9]+\.[0-9]+ ready$"

echo "OK"
