#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# restart-injector.sh — the SCRIPTED FAULT INJECTION for the restart-continuity
# eval (the one novel harness piece). It is NOT a human rescue: like ghost-bug
# plants a bug, this plants a restart at a deterministic checkpoint.
#
# WHAT IT DOES:
#   1. Polls the worker's `ledger` git log for the deterministic trigger — the
#      commit for item 2 landing (>= 2 `feat: item N` commits). Ground-truth,
#      reproducible.
#   2. Records the restart event to $SB/.stev/restart.log: an epoch timestamp
#      (grade.sh splits commits before/after it to prove the worker RESUMED, not
#      front-loaded), the pre-restart HEAD, and the done-items at restart time.
#   3. COLD-restarts the worker: RC_RESTART=1 configure-claude-agent.sh dev —
#      pty kill the session, wipe .claude-session-id + pty.toml (→ fresh transcript),
#      relaunch the SAME identity/persona/repo/bus under a new session name
#      (`run-r<n>`) in the run's decoupled PTY_ROOT (exported below) — teardown
#      stays zero-orphan by killing that whole root.
#
# Runs backgrounded by spin.sh (or standalone). Idempotent guard: injects exactly
# ONE restart per run (a .stev/restart.done stamp).
#
#   ./restart-injector.sh [SANDBOX]
#   env: TRIGGER_AT (default 2 committed items) · POLL_SECS (3) · TIMEOUT_SECS (2700)
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"
L="$SB/ledger"
# Self-isolate to the run's bus root so the cold relaunch binds the ISOLATED bus (never the live network),
# whether we were backgrounded by spin (env already set) or launched standalone.
export ST_ROOT="${ST_ROOT:-$SB/st-root}"   # the isolated convoy net; the cold relaunch (pty restart of rc-dev's agent session) binds it

TRIGGER_AT="${TRIGGER_AT:-2}"
POLL_SECS="${POLL_SECS:-3}"
TIMEOUT_SECS="${TIMEOUT_SECS:-2700}"
mkdir -p "$SB/.stev"
RLOG="$SB/.stev/restart.log"
DONE_STAMP="$SB/.stev/restart.done"

[ -f "$DONE_STAMP" ] && { echo "restart-injector: already injected this run ($DONE_STAMP) — nothing to do"; exit 0; }
[ -d "$L/.git" ] || { echo "restart-injector: no ledger repo at $L — did setup run?" >&2; exit 1; }

# total items = number of `"id":` entries in the work-list (no node dependency here)
TOTAL="$(grep -c '"id":' "$L/items.json" 2>/dev/null || echo 0)"

item_commits() { git -C "$L" log --format='%s' 2>/dev/null | grep -cE '^feat: item ' || true; }

echo "restart-injector: watching $L for >= $TRIGGER_AT item commits (of $TOTAL); poll ${POLL_SECS}s, timeout ${TIMEOUT_SECS}s"
elapsed=0
while :; do
  n="$(item_commits)"
  if [ "$n" -ge "$TRIGGER_AT" ]; then
    break
  fi
  if [ "$elapsed" -ge "$TIMEOUT_SECS" ]; then
    { echo "TIMEOUT ${TIMEOUT_SECS}s reached with only $n/$TRIGGER_AT item commits — NO restart injected."; } | tee -a "$RLOG" >&2
    echo "no_restart reason=timeout item_commits=$n trigger_at=$TRIGGER_AT total=$TOTAL" >> "$RLOG"
    exit 0
  fi
  sleep "$POLL_SECS"; elapsed=$((elapsed + POLL_SECS))
done

n="$(item_commits)"
# If the batch already finished before we caught the checkpoint, a cold restart wouldn't exercise
# resumption (nothing left to do). Record it and skip so the run is re-done for a clean before/after split.
if [ "$n" -ge "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
  echo "restart-injector: batch already complete ($n/$TOTAL) before the checkpoint — resumption NOT exercised; skipping restart (re-run for a clean split)." | tee -a "$RLOG" >&2
  echo "no_restart reason=raced_to_completion item_commits=$n total=$TOTAL" >> "$RLOG"
  exit 0
fi

RESTART_EPOCH="$(date +%s)"
HEAD_SHORT="$(git -C "$L" rev-parse --short HEAD 2>/dev/null)"
DONE_LINES="$(grep -cE '^done: item-' "$L/PROGRESS.md" 2>/dev/null || echo 0)"

{
  echo "# restart-continuity fault injection"
  echo "restart_epoch=$RESTART_EPOCH"
  echo "restart_iso=$(date -u -r "$RESTART_EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "trigger_at=$TRIGGER_AT item_commits_at_restart=$n total_items=$TOTAL progress_done_lines=$DONE_LINES"
  echo "pre_restart_head=$HEAD_SHORT"
  echo "pre_restart_item_commits:"
  git -C "$L" log --format='  %at %h %s' 2>/dev/null | grep -E ' feat: item ' || true
  echo "action=cold_restart_worker gen=1"
} >> "$RLOG"

echo "restart-injector: CHECKPOINT hit ($n item commits) — cold-restarting rc-dev (epoch $RESTART_EPOCH, HEAD $HEAD_SHORT)"
touch "$DONE_STAMP"
RC_RESTART=1 "$HERE/configure-claude-agent.sh" dev "$SB"
echo "restart-injector: cold restart injected. grade.sh will confirm commits straddle epoch $RESTART_EPOCH." | tee -a "$RLOG"
