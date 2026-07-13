#!/usr/bin/env bash
# Launch / cold-restart the restorability worker (rl-wk) via REAL convoy on the ISOLATED net ($ST_ROOT, exported
# by spin.sh).
#
#   ./configure-claude-agent.sh [SANDBOX]              # normal launch (convoy add)
#   RL_RELOAD=1 ./configure-claude-agent.sh [SANDBOX]  # COLD RESTART via `convoy reload` (NO --resume/--session-id)
#
# THE MECHANISM UNDER TEST — `convoy reload rl-wk`: kills + respawns the agent from its STORED pty.toml command,
# which carries NO --resume and NO --session-id => a FRESH transcript (cold boot). The agent's st dir (inbox +
# context/now.md) persists, so the ONLY path back to its working-state is externalization (the SessionStart hook
# injects now.md). Unlike `pty restart`, reload never ATTACHes, so it works from inside a pty and dodges the
# env-leak that caused the incident. This is the real reboot restart path; `st launch` is retired.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
RL_RELOAD="${RL_RELOAD:-}"
NET="${ST_ROOT:?spin.sh must convoy-init + export ST_ROOT to the isolated net ($SB/net) first}"
id="rl-wk"; d="$SB/rl-wk"

if [ -n "$RL_RELOAD" ]; then
  echo "== COLD RESTART ($id): convoy reload — respawn from the stored pty.toml command (NO --resume/--session-id => fresh transcript; inbox + now.md preserved) =="
  # Belt-and-suspenders cold boot; convoy reload's stored command carries no --resume anyway.
  rm -f "$d/.claude-session-id" 2>/dev/null || true
  convoy reload "$id" --network "$NET"
  echo "reloaded $id  (COLD: fresh transcript, same isolated net=$NET, cwd=$d)"
  exit 0
fi

# Normal launch: worker (auto posture; owns its repo; no child agents).
stev_convoy_add "$id" "$d" "auto" "$SB/personas-local/$id.md"
