#!/usr/bin/env bash
# One-time setup: sparse-clones the real beckn/DEG repo this demo runs
# against — just the pieces actually needed, not the whole thing — then
# applies the one local fix discovered while running this on Windows
# (see README.md "Known rough edges" for what it fixes and why).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -d "$HERE/DEG-repo" ]; then
  echo "DEG-repo/ already exists — skipping clone. Delete it first to re-clone from scratch."
else
  echo "Cloning beckn/DEG (sparse checkout — devkits/p2p-trading-ies-wave2, its ledger UI client, and shared scripts only)..."
  git clone --filter=blob:none --no-checkout --depth 1 https://github.com/beckn/DEG.git "$HERE/DEG-repo"
  (
    cd "$HERE/DEG-repo"
    git sparse-checkout init --cone
    git sparse-checkout set devkits/p2p-trading-ies-wave2 devkits/p2p-trading-ies-ledger-ui-client devkits/scripts
    git checkout main
  )
fi

echo "Applying the Windows redocly-shim fix..."
cp "$HERE/patches/run-arazzo-lib.sh" "$HERE/DEG-repo/devkits/scripts/run-arazzo-lib.sh"

echo ""
echo "Setup complete. Next: open RUNBOOK.md and follow it from 'One-time setup'."
