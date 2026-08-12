#!/usr/bin/env bash
#
# Selecting a browser and operating system.
#
# Because vibium sends session.new with empty capabilities (see PROPOSAL.md
# §4.4), the choice travels in the connect URL. Server-side defaults cover the
# common case; this shows the explicit form.
#
#   LT_USERNAME=... LT_ACCESS_KEY=... ./examples/02-choose-browser.sh
#
set -euo pipefail

: "${LT_USERNAME:?set LT_USERNAME}"
: "${LT_ACCESS_KEY:?set LT_ACCESS_KEY}"

BASE_URL="${LT_VIBIUM_URL:-wss://cdp.lambdatest.com/vibium}"

# Build a URL-encoded capability object.
# LT:Options merges key by key server-side, so naming one option does not drop
# the defaults for the others (console and network stay on).
caps_url() {
  local caps="$1"
  local encoded
  encoded=$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$caps")
  printf '%s?capabilities=%s' "$BASE_URL" "$encoded"
}

export VIBIUM_CONNECT_API_KEY="$(printf '%s:%s' "$LT_USERNAME" "$LT_ACCESS_KEY" | base64 | tr -d '\n')"

trap 'vibium stop >/dev/null 2>&1 || true; vibium daemon stop >/dev/null 2>&1 || true' EXIT

run_on() {
  local label="$1" caps="$2"
  printf '\n\033[1;36m▸ %s\033[0m\n' "$label"

  export VIBIUM_CONNECT_URL="$(caps_url "$caps")"

  vibium stop >/dev/null 2>&1 || true
  vibium daemon stop >/dev/null 2>&1 || true

  vibium start >/dev/null
  vibium go https://example.com
  vibium eval 'navigator.userAgent'
}

run_on "Chrome on Windows 11 (defaults)" \
  '{}'

run_on "Edge on Windows 10" \
  '{"browserName":"MicrosoftEdge","LT:Options":{"platformName":"Windows 10"}}'

run_on "Chrome on macOS, named build" \
  '{"browserName":"Chrome","LT:Options":{"platformName":"macOS Ventura","build":"nightly-42"}}'
