#!/usr/bin/env bash
# Launch / cold-restart the restorability CODEX worker (rlx-wk) via REAL convoy (`--harness codex`, ding-default,
# no MCP) on the ISOLATED net ($ST_ROOT, exported by spin.sh).
#
#   ./configure-codex-agent.sh [SANDBOX]              # normal launch (convoy add --harness codex)
#   RL_RELOAD=1 ./configure-codex-agent.sh [SANDBOX]  # COLD RESTART via `convoy reload` (NO --resume/--session-id)
#
# `stev_convoy_add … codex` (lib-harness) is correct-by-construction: it writes the codex rig (codex session +
# AGENTS.md from --persona + a `st ding` wake sidecar, since Codex has no asyncRewake). `convoy reload` respawns
# from the stored pty.toml command — NO --resume/--session-id => fresh transcript (cold boot); the agent's st dir
# (inbox + context/now.md) persists, so the codex SessionStart hook (PR #86) is the only path back to now.md.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/rlx}"
RL_RELOAD="${RL_RELOAD:-}"
NET="${ST_ROOT:?spin.sh must convoy-init + export ST_ROOT to the isolated net ($SB/net) first}"
id="rlx-wk"; d="$SB/rlx-wk"

if [ -n "$RL_RELOAD" ]; then
  echo "== COLD RESTART ($id, codex): convoy reload — respawn from the stored pty.toml command (NO --resume/--session-id => fresh transcript; inbox + now.md preserved) =="
  rm -f "$d/.claude-session-id" 2>/dev/null || true
  convoy reload "$id" --network "$NET"
  echo "reloaded $id  (COLD: fresh transcript, same isolated net=$NET, cwd=$d)"
  exit 0
fi

stev_convoy_add "$id" "$d" "auto" "$SB/personas-local/$id.md" codex
