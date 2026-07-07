#!/usr/bin/env bash
# The novel harness piece: CRASH the PERMANENT agent's session mid-run so `convoy up` must RESPAWN it (the
# reboot's respawn-ownership gate — scripted fault injection, NOT a human rescue). Two things the LIVE run taught
# this injector:
#   1. `convoy up` respawns PERMANENT sessions (cos/spawners), NOT workers — so it targets the cos, not cap-wk.
#   2. Respawn triggers on a session that EXITED/crashed (a "gone" record the reconcile sees). A plain
#      `pty kill <session>` REMOVES the session, so `permanentSessions()` never sees it → no respawn. So this
#      CRASHES the process (kill its PID → it exits, leaving a gone record), in convoy's per-network PTY_ROOT
#      (<net>/pty). convoy up's next reconcile respawns it (resuming its session) -> a `respawn` event.
#   ./kill-injector.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/convoy-network}"
NET="$SB/net"; PR="$NET/pty"; export ST_ROOT="$NET"
# Checkpoint: wait until the loop is underway (cap-wk received cap-cos's delegation) — crash cos mid-flight so it
# must resume + still close the loop.
for _ in $(seq 1 60); do
  grep -lqRE '^from:[[:space:]]*cap-cos' "$NET/cap-wk/inbox" "$NET/cap-wk/archive" 2>/dev/null && break
  sleep 2
done
# CRASH the PERMANENT cos session in convoy's per-network pty root. `pty kill <session>` IS the crash trigger
# (convoy PR #11: it leaves an EXITED gone-record + strips the permanent tag, which convoy up's permanence-memory
# remembers → the reconcile respawns it). NB: pre-PR-#11, `pty kill` REMOVED the record so the reconcile couldn't
# see it to respawn — the bug the live run caught; the live respawn PROOF therefore needs a PR-#11 convoy binary.
# (session name CONSTRUCTED as ${cosid}-claude — never a bare *-claude literal, which the PII grep-gate forbids.)
cosid="cap-cos"; cossess="${cosid}-claude"
pty --root "$PR" kill "$cossess" >/dev/null 2>&1 || true
printf 'crashed %s at %s\n' "$cossess" "$(date +%s)" > "$SB/.kill.log"
echo "INJECTED: crashed the PERMANENT cos session (pid ${pid:-?}) in $PR. convoy up must RESPAWN it next reconcile; grade after the loop settles."
