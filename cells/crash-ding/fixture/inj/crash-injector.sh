#!/usr/bin/env bash
# crash-ding FAULT INJECTOR (the one novel harness piece). It CRASHES the two REAL harness workers —
# cd.cw (claude) and cd.xw (codex) — to prove the crash-notification path is harness-agnostic (it keys on the
# pty SESSION dying, so the same edge must fire for both families). It waits until they're ALIVE (so the
# supervise tick has marked them ever_alive — a not-yet-booted seat crashing is NOT a crash), then
# `st2 pty kill`s them (SIGTERM = a crash: killed/vanished, non-clean death) → st2 sends a "worker crash: <id>"
# bus message up each worker's supervisor chain (cd.sup AND cd.cos). The synthetic controls exit on their own:
# cd.oom exits 137 (nonzero → crash-ding, the exit-code branch); cd.clean exits 0 (clean → SILENT, no ding).
# Then this injector sleeps forever so supervise never respawns it.
set -uo pipefail
S="$CATALOG/.stev"; mkdir -p "$S"; LOG="$S/crash.log"; STAMP="$S/crash.done"
TARGETS="cd.cw cd.xw"
alive(){ st2 pty ls 2>/dev/null | grep -q "($1)"; }
worker_pid(){ st2 pty ls 2>/dev/null | grep -F "($1)" | grep -oE 'pid: [0-9]+' | grep -oE '[0-9]+' | head -1; }

if [ ! -f "$STAMP" ]; then
  # wait until BOTH real workers are alive pty sessions (booted + observable by the supervise tick)
  for t in $TARGETS; do
    n=0; until alive "$t"; do sleep 2; n=$((n+2)); [ "$n" -ge 120 ] && { echo "timeout waiting for $t to boot" >> "$LOG"; break; }; done
  done
  sleep 12  # let the supervise tick observe them alive (set ever_alive) before we crash them
  touch "$STAMP"
  echo "crash_epoch=$(date +%s)" >> "$LOG"
  # SIGKILL (kill -9) the worker's process — NOT `st2 pty kill` (SIGTERM): codex catches SIGTERM and exits 0
  # (a CLEAN exit → no ding), while SIGKILL is uncatchable → the session VANISHES = a non-clean death → a
  # crash-ding for BOTH claude and codex (the harness-agnostic proof).
  for t in $TARGETS; do
    pid="$(worker_pid "$t")"
    if [ -n "$pid" ]; then
      kill -9 "$pid" 2>>"$LOG" && echo "crashed $t (kill -9 pid $pid = SIGKILL → vanished, uncatchable)" >> "$LOG"
    else
      echo "WARN: no pid found for $t in pty ls" >> "$LOG"
    fi
  done
fi
# stay alive so `supervise` never respawns this injector seat
while :; do sleep 3600; done
