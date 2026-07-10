#!/usr/bin/env bash
# Launch one DING-MODE Claude eval agent via REAL convoy — `convoy add` is DING-DEFAULT (no MCP), the
# no-MCP shape the removed `st launch claude --ding` provided. `stev_convoy_add` (lib-harness) does the
# pre-trust + `convoy add` (DING-BUS.md + hooks + pty.toml + persona + `st ding` sidecar) on the ISOLATED
# network ($ST_ROOT, exported by spin.sh). The agent joins via the `st` CLI + ding pokes (no MCP servers).
# Permission POSTURE: SUPERVISOR = bypassPermissions (spawn-capable); WORKER = auto.
#   ./configure-claude-agent.sh <sup|dev> [SANDBOX]   # spin.sh must convoy-init + export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/ding-mode}"

case "$role" in
  sup) id="dm-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  dev) id="dm-dev"; d="$SB/widget"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md"
