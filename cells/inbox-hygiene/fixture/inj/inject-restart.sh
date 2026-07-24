#!/usr/bin/env bash
# st2 folder-format FAULT INJECTOR for inbox-hygiene — the resume double-act hazard, scripted (not a rescue).
# After ih.agent has ACTED on the seeded message (its TOKEN lands in PROCESSED.log), RE-DELIVER the same
# archived message (un-archived) into ih.agent's inbox, then cold-kill ih.agent — the eval's `supervise`
# directive respawns it FROM SPEC (fresh transcript). On re-drain the exactly-once guard must recognize the
# already-handled token and NOT re-append. Then this injector sleeps forever, so supervise never respawns it.
set -uo pipefail
L="$CATALOG/worker"                        # ih.agent's repo (PROCESSED.log)
BUS="$CATALOG/smalltalk"; IB="$BUS/ih.agent"
S="$CATALOG/.stev"; mkdir -p "$S"
RLOG="$S/restart.log"; STAMP="$S/restart.done"
TOKEN="${IH_TOKEN:-IH-9f3a7c2e}"
POLL="${POLL_SECS:-2}"

if [ ! -f "$STAMP" ]; then
  # wait until ih.agent has ACTED (its token is in PROCESSED.log)
  while ! grep -qF "$TOKEN" "$L/PROCESSED.log" 2>/dev/null; do sleep "$POLL"; done
  touch "$STAMP"
  {
    echo "# inbox-hygiene fault injection (st2 supervise)"
    echo "restart_epoch=$(date +%s)"
    echo "token=$TOKEN"
    echo "processed_count_at_inject=$(grep -cF "$TOKEN" "$L/PROCESSED.log" 2>/dev/null)"
  } >> "$RLOG"
  # RE-DELIVER: copy the archived original (carrying the token) back to inbox with a fresh ms-filename —
  # this is the already-handled item a boot re-drain would re-surface.
  mkdir -p "$IB/inbox"
  orig="$(grep -lF "$TOKEN" "$IB/archive"/*.md 2>/dev/null | head -1)"
  if [ -n "$orig" ]; then
    ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' $(( (RANDOM << 8 ^ RANDOM) & 0xffffff )))"
    cp "$orig" "$IB/inbox/${ms}-${sfx}.md"
    echo "re-delivered $(basename "$orig") as ${ms}-${sfx}.md (un-archived)" >> "$RLOG"
  else
    echo "WARN: no archived message carrying $TOKEN found to re-deliver" >> "$RLOG"
  fi
  st2 pty kill ih.agent                    # SIGTERM the seat; `supervise` respawns it FROM SPEC (fresh transcript)
  echo "cold-killed ih.agent — supervise will respawn it" >> "$RLOG"
fi
# stay alive so `supervise` never respawns this injector seat
while :; do sleep 3600; done
