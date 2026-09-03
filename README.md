# P2P Trading — Live Network Demo

A real, live, end-to-end run of the [`beckn/DEG`](https://github.com/beckn/DEG)
peer-to-peer energy trading devkit (`p2p-trading-ies-wave2`) — a rooftop
solar prosumer on TPDDL selling directly to a prosumer on BRPL, a different
Delhi electricity company, over a real signed Beckn 2.0 LTS network. This
repo is what you clone to reproduce that exact run yourself, not a
simulation of it.

**This is the command-line version of the demo.** For the interactive
visual walkthrough of the same trade (click through every hop, see every
payload), see [github.com/Sanjay-dev22/grid-pulse](https://github.com/Sanjay-dev22/grid-pulse)
or the hosted version at **nharuvi.com/beckn**.

## What this actually proves

- A real 12-container Beckn 2.0 LTS network (Docker), each side
  independently signing and verifying every message with Ed25519.
- A real buyer↔seller trade: publish → discover → init → on_init → confirm
  → on_confirm → on_status (settled) — 7 real signed HTTP round-trips.
- Real, policy-computed settlement (OPA/rego) — the ₹437.15 split is
  computed live from the delivered quantities, not typed by hand.
- Real policy **rejection** — a trade from a discom outside the seller's
  allowlist gets a live 400 NACK with a human-readable reason.
- Real persistence to the actual hosted IES ledger service
  (`ies-p2p-energy-ledger.beckn.io`) — independently re-queried afterward
  and confirmed visible, using different credentials than the ones that
  wrote it.

`demo-logs/` holds the real captured output from the run this repo is
built to reproduce — nothing in `RUNBOOK.md` describes anything that wasn't
actually observed.

## Quick start

**Prerequisites:** Git, Docker Desktop, Python 3, Node.js (the runner
installs a pinned copy of `@redocly/cli` on first use).

```bash
git clone <this-repo-url>
cd p2p-trading-live-demo
./setup.sh          # pulls in the real devkit this demo runs, applies one local fix
```

Then open **`RUNBOOK.md`** and follow it from "One-time setup" — it has the
exact commands, in order, including what to say out loud at each step if
you're presenting this live.

## What `setup.sh` does, and why it's needed

This demo runs against the real `beckn/DEG` repository's own devkit — we
don't fork or duplicate it. `setup.sh` does a sparse clone (just the
`p2p-trading-ies-wave2` devkit, its ledger UI client, and shared scripts —
not the whole `beckn/DEG` repo) into `DEG-repo/`, which is gitignored here
since it isn't our content.

It also applies one small fix: the devkit's own Arazzo test runner
(`devkits/scripts/run-arazzo-lib.sh`) has a Windows-specific bug — the
installed `redocly` CLI resolves to a POSIX shell shim rather than its
actual JS entry point on this platform, which crashes with `SyntaxError:
missing ) after argument list`. `patches/run-arazzo-lib.sh` is the real
upstream file with that one line fixed; `setup.sh` copies it into place
after cloning. Everything else in the devkit is untouched, upstream code.

## Known rough edges (real, found while building this)

- The Windows redocly-shim bug above (patched by `setup.sh`).
- Windows Python defaults to `cp1252`, not UTF-8, and chokes on Unicode
  characters in the Beckn OpenAPI spec — `RUNBOOK.md` sets
  `PYTHONUTF8=1` / `PYTHONIOENCODING=utf-8` to fix this.
- The devkit's install script writes to a cache directory before creating
  it, on a first-ever run — `RUNBOOK.md`'s setup step pre-creates it.
- None of these are protocol bugs — all are local dev-tooling friction on
  Windows, not anything wrong with the real network or the trade itself.

## Credit

Built entirely on top of the real, open [`beckn/DEG`](https://github.com/beckn/DEG)
repository and its `p2p-trading-ies-wave2` devkit. This repo adds nothing
to the protocol or the devkit itself — it's a reproducible runbook plus
real evidence from one actual run.
