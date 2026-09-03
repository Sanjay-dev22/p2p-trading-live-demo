# P2P Trading (Wave 2) — Live Demo Runbook

Verified working end-to-end, 2026-09-03/04. This is the exact sequence to
repeat.

> **Haven't run `./setup.sh` yet?** Do that first — it pulls in the real
> devkit this runbook drives and applies one local fix. See the repo
> [README](./README.md) for details.

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

1. Start Docker Desktop.
2. Bring up the stack:
   ```bash
   cd DEG-repo/devkits/p2p-trading-ies-wave2/install
   docker compose up -d
   # wait ~20s, then:
   docker compose ps   # all should show Up / healthy
   ```
3. Make `python3` available (this machine only has `python`):
   ```bash
   export PATH="<repo>/p2p-trading/pybin:$PATH"   # see pybin/python3 shim
   ```
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
   locally (the `.bin/redocly` POSIX-shim bug is fixed there permanently) —
   only the PATH/env exports need doing fresh each session.

## The live run (do this in front of the room)

```bash
cd DEG-repo/devkits/p2p-trading-ies-wave2/uc1/workflows
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
cd ../../p2p-trading-ies-ledger-ui-client
cp example.env .env   # already-provisioned sandbox credentials, safe to reuse
python platform_trade_report.py --from-date 2026-09-01 --to-date 2026-09-05
```
Shows real trade counts pulled from `https://ies-p2p-energy-ledger.beckn.io`
— a genuinely external, hosted service, queried with different credentials
than the ones that wrote the trade. If it 401s on the first try, just retry
once (transient — reproduced once, self-resolved).

## Cleanup afterward
```bash
cd DEG-repo/devkits/p2p-trading-ies-wave2/install
docker compose down
```

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
