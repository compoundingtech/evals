#!/usr/bin/env bash
# Spin the compose-global-skill live layer — Nathan's READ-ONLY existing-skill approach on the DEFAULT config dir
# (real auth; no key; the user's ~/.claude/skills are read, never written). Composes two agents into throwaway
# repos that do NOT contain the skill:
#   • gsw  — kicked with the DOMAIN question whose answer ($SB/.stev/assert, e.g. "xcodebuildmcp") lives ONLY in a
#            GLOBAL skill's body -> must write $SB/repo/GLOBAL_SKILL.txt = that string (proves the global skill fired
#            through the compose; a skill-less agent would answer the raw tool, e.g. "xcodebuild").
#   • gsnc — kicked with an UNRELATED question -> must NOT emit the assert string (a sanity negative control).
# Skips-with-reason if no supported global skill is installed (the box-free NO-SHADOW core carries the proof).
#   ./spin.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
NET="$SB/net"; export ST_ROOT="$NET"
[ -d "$SB/repo/.git" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }

SKILL="$(tr -d '\r\n' < "$SB/.stev/skill" 2>/dev/null)"
DOMAIN="$(tr -d '\r\n' < "$SB/.stev/domain" 2>/dev/null)"
if [ -z "$SKILL" ]; then
  echo "== compose-global-skill LIVE arm SKIPPED: no supported global skill in ~/.claude/skills =="
  echo "   The box-free NO-SHADOW core proves the compose does not shadow global-skill discovery:"
  echo "     $HERE/probe.sh \"$SB\" && $HERE/grade.sh \"$SB\""
  exit 0
fi

stev_init "compose-global-skill" "$SB"
export PTY_ROOT="$(stev_pty_root "$SB")"
STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down ==" >&2; stev_convoy_teardown "$STEV_NET"; stev_teardown "$SB"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/4  convoy init isolated net + a control repo copy =="
stev_convoy_init "$NET"
[ -d "$SB/control/.git" ] || cp -R "$SB/repo" "$SB/control"

echo "== 2/4  compose personas (positive gsw + control gsnc) =="
"$HERE/compose-persona.sh" "$SB" gsw  "$SB/repo"
"$HERE/compose-persona.sh" "$SB" gsnc "$SB/control"

echo "== 3/4  convoy add both on the DEFAULT config dir (real auth; global skills visible) — under test: $SKILL =="
convoy pretrust "$SB/repo" "$SB/control" >/dev/null 2>&1 || true
"$HERE/configure-claude-agent.sh" "$SB" gsw  "$SB/repo"
"$HERE/configure-claude-agent.sh" "$SB" gsnc "$SB/control"

echo "== 4/4  seed the POSITIVE (domain) kick to gsw + a control (unrelated) kick to gsnc =="
seed(){ local who="$1" body="$2"; mkdir -p "$NET/$who/inbox"
  local ms=$(( $(date +%s) * 1000 )); local sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
  printf '%s\n' "$body" > "$NET/$who/inbox/${ms}-${sfx}.md"; echo "   kick -> $NET/$who/inbox/${ms}-${sfx}.md"; }
# Positive: the domain question (never names the assert string), from kick.md with {{DOMAIN}} substituted.
POS="$(sed -n '/^---$/,$p' "$HERE/kick.md" | sed "s#{{DOMAIN}}#$DOMAIN#")"
seed gsw "$POS"
# Control: an unrelated question — the assert string must NOT appear.
seed gsnc $'---\nfrom: requester\nsubject: "global-skill check"\n---\nWhat is the capital of France? Answer with only the city name and write it to a file named GLOBAL_SKILL.txt in your current working directory. When done, reply that the check is done.'

echo
echo "SPUN (compose-global-skill live arm, isolated net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'gsw|gsnc' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE: gsw writes \$SB/repo/GLOBAL_SKILL.txt = '$( tr -d '\r\n' < "$SB/.stev/assert")' (from the $SKILL global skill); gsnc writes a city, not that."
echo "GRADE:    $HERE/grade.sh \"$SB\"   (run probe.sh too for the box-free NO-SHADOW core)"
echo "TEARDOWN: bin/st-evals teardown \"$SB\". Verify ~/.claude/skills unchanged (the eval only READ it)."
