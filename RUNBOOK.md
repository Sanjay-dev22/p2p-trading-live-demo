# P2P Trading (Wave 2) — Live Demo Runbook

Verified working end-to-end, 2026-09-03/04. This is the exact sequence to
repeat.

> **Haven't run `./setup.sh` yet?** Do that first — it pulls in the real
> devkit this runbook drives and applies one local fix. See the repo
> [README](./README.md) for details.

## Before you start: how to read this runbook

- Every gray code box is something you **type into a terminal window**,
  then press Enter — never double-click a `.sh` file in File Explorer /
  Finder. Double-clicking opens a console that runs the script and closes
  itself instantly whether it worked or not, so you can't see what
  happened — always run these from a terminal window you opened yourself
  and that stays open.
- **Windows:** use **Git Bash** (installed with Git for Windows), not
  Command Prompt or PowerShell — every command below is bash syntax.
- **Mac/Linux:** use Terminal.
- **This runbook assumes your terminal is already `cd`'d into this
  repo's folder** (the one `setup.sh` lives in) before Step 1. If a later
  command fails with "no such file or directory," run `pwd` to see where
  you actually are, then navigate back — see Troubleshooting at the
  bottom for exactly how.

## What this proves, live, on stage
- A real 12-container Beckn 2.0 LTS network (Docker), each side independently
  signing/verifying every message with Ed25519.
- A real buyer↔seller P2P energy trade: publish → discover → init → on_init →
  confirm → on_confirm → on_status (settled), 7 real signed HTTP round-trips.
- Real, policy-computed settlement (OPA/rego) — not hand-typed numbers.
- Real policy **rejection** — a trade from a discom outside the seller's
  allowlist gets a live 400 NACK with a human-readable reason.
- Real persistence to the actual hosted IES ledger service
  (`https://ies-p2p-energy-ledger.beckn.io`) — independently re-queried and
  confirmed visible with different credentials than the ones that wrote it.

## One-time setup (do this before the audience arrives)

**Step 0 — anchor your terminal to this repo, once.** Every `cd` in the
rest of this runbook is written relative to this exact spot, so save it
now:
```bash
REPO_ROOT="$(pwd)"
echo "$REPO_ROOT"
```
The path it prints should end in `p2p-trading-live-demo` (or whatever you
named the folder when you cloned it). If it doesn't, `cd` into that folder
first, then re-run the two lines above. **`$REPO_ROOT` is only remembered
for this one terminal window** — if you open a new terminal window later,
redo Step 0 in it before continuing.

**Never type or paste a path yourself here** (e.g. one copied from File
Explorer's address bar, which looks like `C:\Users\...` or `C:/Users/...`).
On Git Bash, a path with a `C:` drive letter silently breaks anything that
uses it later in this runbook, in a way that gives confusing, unrelated-
looking errors — always let `$(pwd)` capture it, exactly as above.

1. Start Docker Desktop, and wait until it says "Docker Desktop is
   running" in its own window (a steady, non-animating whale icon in your
   system tray/menu bar is the same signal).
2. Bring up the stack:
   ```bash
   cd "$REPO_ROOT/DEG-repo/devkits/p2p-trading-ies-wave2/install"
   docker compose up -d
   ```
   Wait about 20 seconds, then check it actually came up:
   ```bash
   docker compose ps
   ```
   Every row's `STATUS` should say `Up ...` (some also show `(healthy)`
   after a few extra seconds — that's expected, not an error). If a row
   says `Exited` or is missing, see Troubleshooting.
3. Make `python3` available. **Most Mac/Linux machines already have
   `python3` — check first, and only apply the fix if you actually need
   it:**
   ```bash
   command -v python3 >/dev/null 2>&1 && echo "python3 already works — skip to step 4" || echo "need the shim below"
   ```
   If it printed "need the shim below" (this is the normal case on
   Windows, which only ships `python`, not `python3`):
   ```bash
   export PATH="$REPO_ROOT/pybin:$PATH"
   command -v python3   # should now print a path ending in .../pybin/python3
   ```
   (This shim ships inside *this* repo, at `pybin/python3` — not in any
   other folder. `$REPO_ROOT` from Step 0 is what makes this work from
   here regardless of which subfolder you're currently `cd`'d into.)

   **One more thing this exact spot needs, on any machine, even one that
   already has a real `python3`:** two Python packages the workflow runner
   and the ledger-report script both need, that a stock Python install
   doesn't come with:
   ```bash
   python3 -m pip install --quiet pyyaml cryptography
   ```
   This is safe to run every time, including on a machine that already has
   them (it just confirms they're there and exits instantly).
4. Force UTF-8 (Windows Python defaults to cp1252, breaks on the spec's own
   Unicode arrows):
   ```bash
   export PYTHONUTF8=1
   export PYTHONIOENCODING=utf-8
   ```
5. Pre-create the Redocly cache dir once (their install script writes to it
   before creating it — a real bug in the devkit, worked around, not fixed
   upstream):
   ```bash
   mkdir -p /tmp/redocly-cli-2.38.0
   ```
   Steps 3–5 are already patched into `DEG-repo/devkits/scripts/run-arazzo-lib.sh`
   by `setup.sh` (the `.bin/redocly` POSIX-shim bug is fixed there
   permanently) — only the PATH/env exports above need doing fresh in
   each new terminal window.

**Quick self-check before the audience arrives** — run this and confirm
it prints real version numbers, not errors, for everything:
```bash
docker compose version && python3 --version && node --version
```

## The live run (do this in front of the room)

```bash
cd "$REPO_ROOT/DEG-repo/devkits/p2p-trading-ies-wave2/uc1/workflows"
./run-arazzo.sh -w publish-catalog -w discover -w select-through-settlement -v
```

Narrate as it scrolls: publish → discover → init/on_init → confirm/on_confirm
→ on_status (settled). It ends with:
```
Workflows: 3 passed, 3 total
Steps: 7 passed, 7 total
Checks: 21 passed, 21 total
NACK check: PASSED — all steps returned ACK.
```
The settlement in the final `on_status` response shows real computed
`revenueFlows`: seller +₹437.15, buyer −₹437.15 (18.5 kWh × ₹12.5 + 14.2 kWh
× ₹14.5), summing to zero across the two roles.

### The "wow" moment — show policy really enforces this

```bash
./run-arazzo.sh -w init-blocked-by-policy -v
```
(Still in the same `uc1/workflows` folder as above — if you closed that
terminal or opened a new one, redo Step 0 and the `cd` above first.)

This one is *supposed* to fail the script's generic NACK scanner — say so
before running it ("watch, this one SHOULD get rejected"). The real payoff is
the live 400 response body:
```
"message": "BAD Request: settlement policy violations: buyer discom
\"TEST_OUTSIDE_DISCOM\" is not allowed to trade with this discom's prosumers
on the test network (allowed: [\"BRPL\", \"PaVVNL\", \"TEST_DISCOM_BUYER\",
\"TEST_DISCOM_SELLER\", \"TPDDL\"])"
```

### Proof it landed on the real, hosted network ledger

```bash
cd "$REPO_ROOT/DEG-repo/devkits/p2p-trading-ies-ledger-ui-client"
cp example.env .env   # already-provisioned sandbox credentials, safe to reuse
python3 platform_trade_report.py --from-date 2026-09-01 --to-date 2026-09-05
```
Shows real trade counts pulled from `https://ies-p2p-energy-ledger.beckn.io`
— a genuinely external, hosted service, queried with different credentials
than the ones that wrote the trade. If it 401s on the first try, just retry
once (transient — reproduced once, self-resolved).

## Cleanup afterward
```bash
cd "$REPO_ROOT/DEG-repo/devkits/p2p-trading-ies-wave2/install"
docker compose down
```

## Troubleshooting

**"no such file or directory" / "cannot find path"**
You're either not `cd`'d into this repo, or `$REPO_ROOT` isn't set in your
*current* terminal window (it doesn't carry over to a new window). Fix:
```bash
cd /path/to/wherever/you/cloned/p2p-trading-live-demo
REPO_ROOT="$(pwd)"
```
then retry the command that failed.

**A tiny console window flashed open and instantly closed**
Something got double-clicked in File Explorer/Finder instead of typed into
an open terminal — most likely `run-arazzo.sh` or `setup.sh`. Nothing in
this runbook should ever be double-clicked; retype the equivalent command
from this file into your terminal instead. If it's genuinely unclear
whether the last command you typed succeeded, scroll up in that same
terminal window — the full output is still there.

**`python3: command not found` even after Step 3's export**
Check you're using the value from *this session's* Step 0 — `$REPO_ROOT`
resets every new terminal window. Run `echo "$REPO_ROOT"` — if it prints
nothing, redo Step 0, then Step 3's export again.

**`docker compose ps` shows a row as `Exited` or missing**
Run `docker compose logs <container-name>` to see why. Usually this means
a previous run wasn't fully stopped — run `docker compose down` then
`docker compose up -d` again from the same folder.

**The `platform_trade_report.py` 401s**
Retry once — this has been transient every time it's happened, and
self-resolves.

## Known rough edges (don't demo these, just know them for Q&A)
- Three real bugs found and fixed locally in the devkit's own tooling
  (Windows-only): missing `mkdir` before a cache write, cp1252 vs UTF-8
  encoding on two separate Python scripts, and a POSIX-shell-vs-JS mismatch
  in the installed `redocly` CLI shim. None are protocol bugs — all are
  local dev-tooling friction, already fixed in this checkout.
- The full wave2 devkit models 14 workflows across 6 actors (buyer, seller,
  both discom ledgers, both discom "actors"). We're only running the core 3
  plus the policy-rejection case — the rest (meter-data sub-transactions,
  cascaded settlement pushes) are real but not needed for this story.

## Prefer clicking to typing commands?

This runbook drives the original, scripted command-line version of this
demo. A newer, interactive version — two real web apps you click through
instead of a terminal script, with the exact same real network underneath
— lives at
[github.com/Sanjay-dev22/p2p-trading-demo-app](https://github.com/Sanjay-dev22/p2p-trading-demo-app),
and is the easier starting point if you're new to the command line.
