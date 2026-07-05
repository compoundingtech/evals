#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# st-evals readiness — the first-boot smoke suite. Answers "is this setup wired
# well enough to run agent-team evals at all?" before you invest in a full cell.
#
# It checks, in order:
#   1. capabilities (preflight) — what's installed, how many families, cross-family judging
#   2. the ESSENTIALS via the hermetic `bootstrap-network` cell (offline, throwaway sandbox):
#        A init a fresh network + a CoS comes online
#        B the CoS boot ritual works (status + inbox drain)
#        C the CoS can SPAWN a specialist (launch generates a bootable harness)
#        D the two exchange a message end-to-end, correctly attributed
#
# Exit 0 = READY (the essentials passed). Exit 1 = a hard essential failed (can't
# spawn / can't message) — those block; everything else is reported as a finding.
#
#   st-evals readiness [SANDBOX_DIR]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SANDBOX="${1:-${EVAL_SANDBOX:-$ROOT/.sandbox}/readiness}"

echo "═══ st-evals readiness ═══"
echo
echo "── 1. capabilities ──"
"$HERE/preflight.sh" || true

echo
echo "── 2. essentials (hermetic bootstrap-network smoke) ──"
BN="$ROOT/cells/bootstrap-network/fixture/run.sh"
if [ ! -x "$BN" ]; then
  echo "  ✗ bootstrap-network runner missing ($BN) — cannot verify the essentials"; exit 1
fi
if "$BN" "$SANDBOX"; then
  echo
  echo "✓ READY — the bus works, a CoS spawns a specialist, and messages round-trip."
  echo "  Next: st-evals list  → pick a cell your setup supports (st-evals preflight)."
  exit 0
else
  echo
  echo "✗ NOT READY — an essential gate failed above (spawn or message round-trip)."
  echo "  Fix the ✗/⚠ items, then re-run: st-evals readiness"
  exit 1
fi
