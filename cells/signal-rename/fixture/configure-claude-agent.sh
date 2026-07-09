#!/usr/bin/env bash
# Launch one signal rename Claude eval agent via REAL convoy (ding-default, no MCP — the removed `st launch` is
# gone). `stev_convoy_add` (lib-harness) does pre-trust + `convoy add` (correct-by-construction:
# hooks/pty.toml/persona/ding sidecar) on the ISOLATED network ($ST_ROOT, exported by spin.sh).
# Permission POSTURE (Nathan's rule): SUPERVISOR = bypassPermissions (spawn-capable); WORKER = auto.
#   ./configure-claude-agent.sh <role> [SANDBOX]   # spin.sh must export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/signal-rename}"
case "$role" in
  sup)   id="sig-sup";   d="$SB/sup";   mode="bypassPermissions" ;;   # integration lead; owns app.toml
  base)  id="sig-base";  d="$SB/base";  mode="auto" ;;                # owns the base package
  relay) id="sig-relay"; d="$SB/relay"; mode="auto" ;;                # owns signal-relay (the trap repo)
  hub)   id="sig-hub";   d="$SB/hub";   mode="auto" ;;                # owns signal-hub (the scheme)
  *) echo "role must be sup|base|relay|hub" >&2; exit 1 ;;
esac

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md"
