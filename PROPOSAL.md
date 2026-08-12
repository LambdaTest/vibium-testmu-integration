# Proposal: Vibium ↔ TestMu AI cloud grid integration

**To:** Vibium maintainers and community

**From:** TestMu AI engineering

**Vibium version tested:** v26.5.31

**Status:** Working prototype, verified end to end. Open for review.

**Date:** 11 August 2026

---

## Contents

1. [Objective](#1-objective)
2. [Design goals](#2-design-goals)
3. [Phase 1 integration](#3-phase-1-integration)
4. [Technical details](#4-technical-details)
5. [User journey](#5-user-journey)
6. [Roadmap](#6-roadmap)
7. [Appendix: what we verified](#appendix-what-we-verified)

---

## 1. Objective

Let anyone using the vibium CLI run their automation on a cloud browser instead of a local
one, by changing a single environment variable.

```sh
export VIBIUM_CONNECT_URL="wss://cdp.lambdatest.com/vibium"
vibium go https://example.com
```

Every other vibium command stays exactly as it is. No SDK, no wrapper, no plugin, no
changes to the user's scripts.

### Why this matters to vibium

Vibium is built for AI agents, and ships an MCP server so agents can drive a browser
directly. Today an agent gets **one** browser — whatever runs on the machine hosting the
daemon. Cloud grid support turns that into thousands of browser/OS combinations running in
parallel.


### Why this matters to us

We run 3000+ browsers and 10,000+ real devices. Vibium is, as far as we can tell, the
first automation tool designed for agents rather than adapted for them, and it is built on
the W3C WebDriver BiDi standard we already serve. We would like it to work well with our
grid, and we would like the mechanism to be one **any** grid can implement — not a
TestMu AI specific fork.

---

## 2. Design goals

These are the constraints we set ourselves, in priority order.

### G1 — No changes to user scripts

A vibium script that runs locally must run on the grid unmodified. The connection URL is
the only difference. This is the whole proposition; anything that breaks it is a
non-starter.

### G2 — No changes required in vibium for Phase 1

We should be able to ship this without waiting on upstream. Anything that needs a vibium
change belongs in a later phase, proposed here for discussion rather than assumed.

### G3 — The mechanism should be provider-neutral

Whatever makes vibium work with our grid should work with any BiDi-capable grid. We are
proposing a general mechanism and implementing it for ourselves, not asking for special
handling.

### G4 — Standards-compliant BiDi, no proprietary extensions

We relay W3C WebDriver BiDi. No custom commands are required to make the basic flow work.
Vendor-specific additions (e.g. marking a test pass/fail) must be optional and never
required for correctness.

### G5 — Credentials never travel in URLs

Query strings end up in proxy logs, browser history, shell history and CI output. Auth
belongs in a header.

---

## 3. Phase 1 integration

**Scope:** the vibium CLI connects to a TestMu AI browser and runs the full command
surface. No vibium changes required.

### What we propose

A `/vibium` endpoint on our hub. A user connects a WebSocket to it; we authenticate, create
the test record, allocate a VM, start browser, and then relay
WebDriver BiDi frames between the client and the browser for the life of the session.

```
vibium CLI ──WebSocket──► TestMu /vibium ──► [ create test → allocate VM → setup ]
                                              └─► chromedriver BiDi ──► Chrome
```

### What Phase 1 deliberately does not include

- Changes to vibium itself
- A TestMu AI SDK or wrapper — [G1](#g1--no-changes-to-user-scripts) rules it out
- Tunnel support for local applications (Phase 2)
- A vendor command for test pass/fail status (Phase 2)

---

## 4. Technical details

### 4.1 Connection flow

```
1. Client opens WebSocket to wss://cdp.lambdatest.com/vibium
   with Authorization: Bearer base64("username:accessKey")

2. Grid authenticates, then provisions:
     create test record → allocate VM → set up VM

3. Grid starts a chrome session,
   which exposes a BiDi endpoint on the node

4. Grid completes the WebSocket upgrade to the client

5. Client sends session.new  →  grid answers it

6. All other frames relay verbatim, both directions,
   until the client disconnectsals

7. Disconnect → grid completes the test and releases the VM
```

### 4.2 Authentication

We use the bearer token vibium already supports:

```sh
export VIBIUM_CONNECT_API_KEY="$(printf '%s:%s' "$LT_USERNAME" "$LT_ACCESS_KEY" | base64)"
```

The grid decodes `base64("username:accessKey")`. This satisfies [G5](#g5--credentials-never-travel-in-urls):
credentials go in a header, never a query string.

We verified vibium sends this correctly on both `vibium start` and `vibium mcp`.

### 4.4 Browser and OS selection
Vibium opens every remote connection by sending:

```json
{"id":1,"method":"session.new","params":{"capabilities":{}}}
```

Because `session.new` carries no capabilities, selection has to travel out of band. We use
a query parameter, mirroring how our existing Playwright endpoint works:

```sh
# defaults: Chrome latest on Windows 11
export VIBIUM_CONNECT_URL="wss://cdp.lambdatest.com/vibium"

# explicit
CAPS='{"browserName":"Chrome","LT:Options":{"platformName":"Windows 10"}}'
export VIBIUM_CONNECT_URL="wss://cdp.lambdatest.com/vibium?capabilities=$(urlencode "$CAPS")"
```

Server-side defaults mean the common case needs no capabilities at all. Options merge key
by key, so overriding the OS does not silently drop other settings.

---

## 5. User journey

### 5.1 First run

Install:

```sh
npm install -g vibium
```

Grid-only users can skip the local Chrome download entirely — a remote connection never
launches one:

```sh
VIBIUM_SKIP_BROWSER_DOWNLOAD=1 npm install -g vibium
```

Configure once:

```sh
export LT_USERNAME="your-username"
export LT_ACCESS_KEY="your-access-key"

export VIBIUM_CONNECT_URL="wss://cdp.lambdatest.com/vibium"
export VIBIUM_CONNECT_API_KEY="$(printf '%s:%s' "$LT_USERNAME" "$LT_ACCESS_KEY" | base64 | tr -d '\n')"
```

Run — identical to local vibium:

```sh
vibium start
vibium go https://example.com
vibium map
vibium click @e1
vibium screenshot -o result.png
vibium stop
```

Only the first command is slow; it provisions the browser. Everything after is fast.

### 5.2 Choosing a browser

```sh
export VIBIUM_CONNECT_URL="wss://cdp.lambdatest.com/vibium?capabilities=$(
  node -e 'console.log(encodeURIComponent(JSON.stringify({
    browserName: "Chrome",
    "LT:Options": { platformName: "Windows 10", build: "nightly" }
  })))')"
```

### 5.3 Running in CI

```sh
trap 'vibium stop; vibium daemon stop' EXIT

vibium start
vibium go "$STAGING_URL"
vibium wait text "Dashboard" --timeout 20000
vibium screenshot -o artifacts/dashboard.png
```

The `trap` matters: `vibium stop` is what releases the cloud VM.

Verified with two concurrent sessions on different operating systems.

---

## Feedback we are looking for

1. **Is `session.new` interception acceptable** as the grid-side mechanism, or would you
   prefer any other approach?
2. **Is a `/vibium` path the right shape** for a grid endpoint, or please suggest any other approach.

Contact and repository details are in [`README.md`](README.md).
