#!/usr/bin/env bash
# Spin the INBOX-HYGIENE cell via REAL convoy (convoy add, ding-default): one agent (ih-agent) that must
# process each inbox message exactly once and ARCHIVE the moment it acts. SELF-ISOLATING: convoy init an
# isolated net at $SB/st-root so nothing touches the live convoy. Seeds ONE token-carrying kick, then arms
# inject-restart.sh which — once the agent has acted — RE-DELIVERS the same message un-archived + cold-
# restarts the agent, exercising the resume double-act guard. The grader proves the token landed EXACTLY once.
#   ./spin.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/inbox-hygiene}"
NET="$SB/st-root"; export ST_ROOT="$NET"

[ -d "$SB/repo" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"
echo "== 2/5  compose persona =="
"$HERE/compose-persona.sh" "$SB"
echo "== 3/5  launch ih-agent (convoy add: auto, owns its repo) =="
"$HERE/configure-claude-agent.sh" "$SB"

echo "== 4/5  seed ONE token-carrying kick into ih-agent's inbox =="
mkdir -p "$NET/ih-agent/inbox" "$SB/.stev"
TOKEN="IH-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf '%s\n' "$TOKEN" > "$SB/.stev/token"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed 's/__IH_TOKEN__/'"$TOKEN"'/' "$HERE/kick.md" | sed -n '/^---$/,$p' > "$NET/ih-agent/inbox/${ms}-${sfx}.md"
echo "   token=$TOKEN seeded $NET/ih-agent/inbox/${ms}-${sfx}.md"

echo "== 5/5  arm the double-act injector (background) =="
nohup "$HERE/inject-restart.sh" "$SB" >> "$SB/.stev/injector.out" 2>&1 &
disown 2>/dev/null || true
echo "   inject-restart backgrounded (pid $!); log: $SB/.stev/injector.out"

echo
echo "SPUN (inbox-hygiene, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'ih-agent' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): ih-agent boots -> appends TOKEN once to repo/PROCESSED.log + ARCHIVES the msg."
echo "  Then inject-restart RE-DELIVERS the same msg un-archived + cold-restarts ih-agent; on re-drain it must"
echo "  recognize the already-processed token and NOT re-append. GRADE proves PROCESSED.log has the token EXACTLY once."
echo "GRADE:     $HERE/grade.sh \"$SB\""
echo "TEARDOWN:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
