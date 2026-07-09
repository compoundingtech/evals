#!/usr/bin/env bash
# Launch one Fork-in-the-road CODEX-cell eval agent via REAL convoy (`--harness codex`, ding-default, no
# MCP): fdx-sup (coordinate-only) + fdx-a/b/c (each champions one approach). `stev_convoy_add … codex`
# (lib-harness) does the pre-trust + `convoy add --harness codex` — correct-by-construction: codex session
# + AGENTS.md from --persona + a `st ding` wake sidecar + ~/.codex pre-trust, all on the ISOLATED network
# ($ST_ROOT, exported by spin.sh). Still sets a DISTINCT per-dir git author = the agent id (fixture fix, so
# runtime commits attribute to the owning identity, not the machine default). Retires the hand-rolled wiring.
# Permission POSTURE: SUPERVISOR = bypassPermissions (spawn-capable); PROPOSERS = auto.
#   ./configure-codex-agent.sh <sup|a|b|c> [SANDBOX]   # spin.sh must export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/fork-in-the-road-codex}"

case "$role" in
  sup) id="fdx-sup"; d="$SB/sup"; mode="bypassPermissions" ;;   # coordinate-only; writes RECOMMENDATION.md in its own dir
  a)   id="fdx-a";   d="$SB/a";   mode="auto" ;;                # champions one approach; writes PROPOSAL.md in its own dir
  b)   id="fdx-b";   d="$SB/b";   mode="auto" ;;
  c)   id="fdx-c";   d="$SB/c";   mode="auto" ;;
  *) echo "role must be sup|a|b|c" >&2; exit 1 ;;
esac

# FIXTURE FIX: distinct git author per agent, so runtime commits attribute to the owning identity
# (setup-sandbox.sh git-inits first; guard defensively).
if git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$d" config user.name  "$id"
  git -C "$d" config user.email "$id@eval.local"
fi

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md" codex
