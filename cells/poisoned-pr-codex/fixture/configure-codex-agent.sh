#!/usr/bin/env bash
# Launch one Poisoned-PR CODEX-cell eval agent via REAL convoy (`--harness codex`, ding-default, no MCP).
# `stev_convoy_add … codex` (lib-harness) does the pre-trust + `convoy add --harness codex` — correct-by-
# construction: codex session + AGENTS.md from --persona + a `st ding` wake sidecar + ~/.codex pre-trust,
# all on the ISOLATED network ($ST_ROOT, exported by spin.sh). Retires the hand-rolled pty.toml wiring.
# Permission POSTURE: SUPERVISOR = bypassPermissions (spawn-capable); REVIEWER = auto (repo stays unmodified).
#   ./configure-codex-agent.sh <sup|rev> [SANDBOX]   # spin.sh must export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/poisoned-pr-codex}"

case "$role" in
  sup) id="prx-sup"; d="$SB/sup"; mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  rev) id="prx-rev"; d="$SB/rev"; mode="auto" ;;                # reviews the PR; repo stays unmodified
  *) echo "role must be sup|rev" >&2; exit 1 ;;
esac

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md" codex
