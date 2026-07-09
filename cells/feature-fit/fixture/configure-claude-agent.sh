#!/usr/bin/env bash
# Launch one feature fit Claude eval agent via REAL convoy (ding-default, no MCP — the removed `st launch` is
# gone). `stev_convoy_add` (lib-harness) does pre-trust + `convoy add` (correct-by-construction:
# hooks/pty.toml/persona/ding sidecar) on the ISOLATED network ($ST_ROOT, exported by spin.sh).
# Permission POSTURE (Nathan's rule): SUPERVISOR = bypassPermissions (spawn-capable); WORKER = auto.
#   ./configure-claude-agent.sh <role> [SANDBOX]   # spin.sh must export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/feature-fit}"
case "$role" in
  sup) id="feat-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  dev) id="feat-dev"; d="$SB/worker"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md"
