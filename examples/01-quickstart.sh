#!/usr/bin/env bash
#
# Quickstart: run vibium against a TestMu cloud browser.
#
# This is the whole integration — two environment variables, then ordinary
# vibium commands. Nothing here is TestMu-specific except the URL.
#
#   LT_USERNAME=... LT_ACCESS_KEY=... ./examples/01-quickstart.sh
#
set -euo pipefail

: "${LT_USERNAME:?set LT_USERNAME}"
: "${LT_ACCESS_KEY:?set LT_ACCESS_KEY}"

# The endpoint. Server-side defaults are Chrome latest on Windows 11, so the
# common case needs no capabilities at all.
export VIBIUM_CONNECT_URL="${LT_VIBIUM_URL:-wss://cdp.lambdatest.com/vibium}"

# Credentials travel in the Authorization header, never the URL.
# tr -d '\n' matters: GNU base64 wraps long lines, and a newline in a header
# breaks the request.
export VIBIUM_CONNECT_API_KEY="$(printf '%s:%s' "$LT_USERNAME" "$LT_ACCESS_KEY" | base64 | tr -d '\n')"

# vibium stop is what releases the cloud VM. Without this, a crash or Ctrl-C
# leaves it allocated until the idle timeout expires.
trap 'vibium stop >/dev/null 2>&1 || true; vibium daemon stop >/dev/null 2>&1 || true' EXIT

step() { printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }

step "Connect"
# start only records the URL; no network call happens yet.
vibium start

step "Navigate (this provisions the browser — 15-30s)"
vibium go https://example.com

step "Confirm we are on the grid, not a local browser"
vibium eval 'navigator.userAgent'

step "Read the page"
vibium title
vibium text h1

step "Discover elements"
vibium map

step "Interact"
vibium click "a"
vibium url
vibium back

step "Capture"
vibium screenshot -o quickstart.png

step "Done — the trap will release the session"
