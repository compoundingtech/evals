#!/usr/bin/env bash
# st2 folder-format FAULT INJECTOR for restart-continuity — the one novel harness piece. It is NOT a human
# rescue: like ghost-bug plants a bug, this plants a COLD RESTART at a deterministic checkpoint. It watches
# the ledger repo for item-2's commit, records the restart event to restart.log, then cold-kills rc.dev.
# The eval's `supervise` directive respawns rc.dev FROM SPEC (cold, full env) — which must resume the batch
# LOSSLESSLY from the durable substrate (git + PROGRESS.md + items.json + bus). Then this injector stays
# alive forever, so `supervise` never respawns THIS seat. Invisible to the team (its own dir, no bus voice).
set -uo pipefail
L="$CATALOG/worker"                        # the ledger repo in the copied catalog world
S="$CATALOG/.stev"; mkdir -p "$S"
RLOG="$S/restart.log"; STAMP="$S/restart.done"
TRIGGER_AT="${TRIGGER_AT:-2}"; POLL="${POLL_SECS:-3}"
item_commits(){ git -C "$L" log --format='%s' 2>/dev/null | grep -cE '^feat: item ' || true; }

if [ ! -f "$STAMP" ]; then
  # wait for the deterministic checkpoint: >= TRIGGER_AT item commits (item-2 landed)
  while [ "$(item_commits)" -lt "$TRIGGER_AT" ]; do sleep "$POLL"; done
  n="$(item_commits)"; TOTAL="$(grep -c '"id":' "$L/items.json" 2>/dev/null || echo 0)"
  # if the batch already finished before we caught the checkpoint, a restart wouldn't exercise resumption
  if [ "$n" -ge "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    echo "no_restart reason=raced_to_completion item_commits=$n total=$TOTAL" >> "$RLOG"
  else
    touch "$STAMP"
    {
      echo "# restart-continuity fault injection (st2 supervise)"
      echo "restart_epoch=$(date +%s)"
      echo "trigger_at=$TRIGGER_AT item_commits_at_restart=$n total_items=$TOTAL"
      echo "pre_restart_head=$(git -C "$L" rev-parse --short HEAD 2>/dev/null)"
      echo "pre_restart_item_commits:"
      git -C "$L" log --format='  %at %h %s' 2>/dev/null | grep -E ' feat: item ' || true
      echo "action=cold_restart_worker gen=1"
    } >> "$RLOG"
    st2 pty kill rc.dev                    # SIGTERM the seat; `supervise` respawns it FROM SPEC (cold)
    echo "injected: cold-killed rc.dev at $n item commits — supervise will respawn it." >> "$RLOG"
  fi
fi
# stay alive so `supervise` never respawns this injector seat
while :; do sleep 3600; done
