#!/usr/bin/env bash
# Launch one tui build Claude eval agent via REAL convoy (ding-default, no MCP — the removed `st launch` is
# gone). `stev_convoy_add` (lib-harness) does pre-trust + `convoy add` (correct-by-construction:
# hooks/pty.toml/persona/ding sidecar) on the ISOLATED network ($ST_ROOT, exported by spin.sh).
# Permission POSTURE (Nathan's rule): SUPERVISOR = bypassPermissions (spawn-capable); WORKER = auto.
#   ./configure-claude-agent.sh <role> [SANDBOX]   # spin.sh must export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"
case "$role" in
  sup)   id="tui-sup";   d="$SB/sup";   mode="bypassPermissions" ;;   # integration lead; owns shared data layer
  tree)  id="tui-tree";  d="$SB/tree";  mode="auto" ;;                # owns the tree view
  cards) id="tui-cards"; d="$SB/cards"; mode="auto" ;;                # owns the cards view
  ux)    id="tui-ux";    d="$SB/ux";    mode="auto" ;;                # usability reviewer; authors NO product code
  *) echo "role must be sup|tree|cards|ux" >&2; exit 1 ;;
esac

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md"
