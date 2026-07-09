#!/usr/bin/env bash
# Launch one Ghost-bug CODEX-cell eval agent via REAL convoy (`--harness codex`, ding-default, no MCP).
# `stev_convoy_add … codex` (lib-harness) does the pre-trust + `convoy add --harness codex` — which is
# correct-by-construction: it writes the codex rig (codex session + AGENTS.md from --persona + a `st ding`
# wake sidecar, since Codex has no asyncRewake + ~/.codex/config.toml pre-trust) on the ISOLATED network
# ($ST_ROOT, exported by spin.sh). This retires the old hand-rolled pty.toml / hardcoded default-root wiring.
# Permission POSTURE (Nathan's rule): SUPERVISOR = bypassPermissions (spawn-capable); WORKER = auto.
#   ./configure-codex-agent.sh <sup|fix> [SANDBOX]   # spin.sh must export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex}"

case "$role" in
  sup) id="gbx-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  fix) id="gbx-fix"; d="$SB/worker"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|fix" >&2; exit 1 ;;
esac

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md" codex
