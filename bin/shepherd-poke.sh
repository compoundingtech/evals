#!/usr/bin/env bash
# shepherd-poke — work around HB-4 (idle Claude Code agents don't reliably wake on
# delivered coord messages) for a team eval. Every INTERVAL, for each agent: if it's
# IDLE (the harness "esc to interrupt" busy-line is absent) and has messages sitting
# in its inbox that we haven't poked it about yet, send a wake poke (clear the input
# line, then a short pointer + return — never the message content; the message is
# already delivered). Pokes are the HB-4 tax, tracked separately from real rescues.
#
#   ./shepherd-poke.sh "tui-sup tui-tree tui-cards tui-ux" [INTERVAL_SEC] [MAX_ITERS]
set -uo pipefail
AGENTS=(${1:-"tui-sup tui-tree tui-cards tui-ux"})
INTERVAL="${2:-40}"
MAX="${3:-180}"                 # ~2h at 40s
ROOT="$HOME/.local/state/smalltalk"
declare -A LASTPOKE               # agent -> inbox count we last poked about
LOG="${ST_EVALS_LOG:-${TMPDIR:-/tmp}/st-evals-shepherd.log}"
echo "shepherd start $(date +%H:%M:%S) agents=${AGENTS[*]} interval=${INTERVAL}s" >> "$LOG"

# Baseline to the CURRENT inbox so we don't re-poke about briefs already delivered/handled.
for a in "${AGENTS[@]}"; do LASTPOKE[$a]=$(ls "$ROOT/$a/inbox/"*.md 2>/dev/null | wc -l | tr -d ' '); done

for ((i=0; i<MAX; i++)); do
  for a in "${AGENTS[@]}"; do
    inbox=$(ls "$ROOT/$a/inbox/"*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$inbox" -eq 0 ] && { LASTPOKE[$a]=0; continue; }
    [ "$inbox" -eq "${LASTPOKE[$a]}" ] && continue         # already poked about this backlog
    screen=$(pty peek --plain "$a-claude" 2>/dev/null | tail -3)
    if printf '%s' "$screen" | grep -q "esc to interrupt"; then
      continue                                             # busy — leave it alone
    fi
    # idle + unread it hasn't been poked about -> wake it
    pty send "$a-claude" --with-delay 0.4 \
      --seq "key:ctrl+u" \
      --seq "You have $inbox unread coord message(s) — read your inbox and proceed." \
      --seq "key:return" >/dev/null 2>&1
    LASTPOKE[$a]=$inbox
    echo "$(date +%H:%M:%S) poked $a (inbox=$inbox)" >> "$LOG"
  done
  sleep "$INTERVAL"
done
echo "shepherd stop $(date +%H:%M:%S) after $MAX iters" >> "$LOG"
