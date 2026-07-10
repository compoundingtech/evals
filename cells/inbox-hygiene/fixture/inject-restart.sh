#!/usr/bin/env bash
# The SCRIPTED FAULT INJECTION for inbox-hygiene: once ih-agent has ACTED on the seeded message (its token
# appears in PROCESSED.log), simulate the exact resume-safety hazard — RE-DELIVER the same message
# (un-archived) into the inbox, then COLD-RESTART the agent (pty restart -y = respawn from the pty.toml,
# no --resume, so a fresh transcript; inbox is preserved). On re-drain the agent sees an already-handled
# item; the guard must stop it re-appending. Injects ONCE (a .stev/restart.done stamp).
#   ./inject-restart.sh [SANDBOX]     env: POLL_SECS(2) TIMEOUT_SECS(300)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/inbox-hygiene}"
export ST_ROOT="${ST_ROOT:-$SB/st-root}"; NET="$ST_ROOT"
TOKEN="$(cat "$SB/.stev/token" 2>/dev/null)"
POLL="${POLL_SECS:-2}"; TIMEOUT="${TIMEOUT_SECS:-300}"
mkdir -p "$SB/.stev"; DONE="$SB/.stev/restart.done"; RLOG="$SB/.stev/restart.log"
[ -f "$DONE" ] && { echo "inject-restart: already injected"; exit 0; }
[ -n "$TOKEN" ] || { echo "inject-restart: no token" >&2; exit 1; }

elapsed=0
while :; do
  if grep -qF "$TOKEN" "$SB/repo/PROCESSED.log" 2>/dev/null; then break; fi
  [ "$elapsed" -ge "$TIMEOUT" ] && { echo "no_restart reason=timeout token_absent" >> "$RLOG"; exit 0; }
  sleep "$POLL"; elapsed=$((elapsed+POLL))
done

touch "$DONE"
{ echo "# inbox-hygiene fault injection"; echo "restart_epoch=$(date +%s)"; echo "token=$TOKEN"
  echo "processed_count_at_inject=$(grep -cF "$TOKEN" "$SB/repo/PROCESSED.log" 2>/dev/null)"; } >> "$RLOG"

# RE-DELIVER the same message (un-archived) — this is the item a boot re-drain would re-surface.
mkdir -p "$NET/ih-agent/inbox"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed 's/__IH_TOKEN__/'"$TOKEN"'/' "$HERE/kick.md" | sed -n '/^---$/,$p' > "$NET/ih-agent/inbox/${ms}-${sfx}.md"
echo "inject-restart: re-delivered token $TOKEN (un-archived), cold-restarting ih-agent" | tee -a "$RLOG"
# COLD restart the agent session (respawn from convoy's pty.toml; inbox with the re-delivered msg persists).
pty --root "$NET/pty" restart -y "silber.ih-agent-claude" 2>&1 | tail -1 | tee -a "$RLOG"
