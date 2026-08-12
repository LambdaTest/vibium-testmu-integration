# Vibium ↔ TestMu AI

A proposal for running [Vibium](https://github.com/VibiumDev/vibium) against cloud
browsers, with a working reference implementation and runnable examples.

**This repository is for review and discussion.** It is not a product, an SDK, or a
pull request against vibium.

---

## Start here

**[PROPOSAL.md](PROPOSAL.md)** — objective, design goals, phase 1 scope, technical
details, user journey and roadmap.

---

## The short version

Run vibium against a cloud browser by changing one environment variable:

```sh
export VIBIUM_CONNECT_URL="wss://cdp.lambdatest.com/vibium"
export VIBIUM_CONNECT_API_KEY="$(printf '%s:%s' "$LT_USERNAME" "$LT_ACCESS_KEY" | base64 | tr -d '\n')"

vibium start
vibium go https://example.com
vibium stop
```

Every other vibium command is unchanged. No SDK, no wrapper, no script changes.

We have this working: vibium on macOS driving Chrome 150 on a Windows 11 cloud VM, with
roughly 60 commands verified. See the appendix in the proposal for the full list.

---

## What is here

| Path | |
|---|---|
| [`PROPOSAL.md`](PROPOSAL.md) | The proposal |
| [`examples/01-quickstart.sh`](examples/01-quickstart.sh) | Minimal end-to-end run |
| [`examples/02-choose-browser.sh`](examples/02-choose-browser.sh) | Selecting browser and OS |
| [`examples/04-mcp-config.json`](examples/04-mcp-config.json) | Driving a cloud browser from an AI agent |

---

## Feedback

Questions we would most like answered are listed at the end of
[PROPOSAL.md](PROPOSAL.md#feedback-we-are-looking-for). Issues and PRs on this repository
are welcome, as is any other channel the maintainers prefer.

Licensed under Apache-2.0, matching vibium.
