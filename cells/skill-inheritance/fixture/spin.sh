#!/usr/bin/env bash
# Spin the SKILL-INHERITANCE cell via REAL convoy (convoy add, ding-default): one worker (si-agent) that
# must run the "eval skill-inheritance check" — invoke every skill it INHERITED and follow each one's body.
# It proves a convoy worker inherits user-brought skills across TWO scopes as a UNION:
#   • PROJECT scope — <repo>/.claude/skills/evalskill-project (auto-loads via --dir; no injection)
#   • PLUGIN  scope — a local plugin (evalpkg) loaded via `claude --plugin-dir` (injected in configure)
# Each skill's SECRET TOKEN lives only in its body (never in the kick), so a sentinel bearing the right token
# proves that skill actually loaded + fired. SELF-ISOLATING: an isolated convoy net at $SB/st-root — nothing
# touches the live convoy, and NOTHING is written under ~/.claude/skills (personal scope untouched).
#   ./spin.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/skill-inheritance}"
NET="$SB/st-root"; export ST_ROOT="$NET"

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  materialize the sandbox (project skill + local plugin + per-run secret tokens) =="
"$HERE/setup-sandbox.sh" "$SB"

echo "== 2/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 3/5  compose persona =="
"$HERE/compose-persona.sh" "$SB"

echo "== 4/5  launch si-agent (convoy add auto) + inject --plugin-dir (plugin scope) + restart =="
"$HERE/configure-claude-agent.sh" "$SB"

echo "== 5/5  seed the check kick into si-agent's inbox (delivered post-restart, plugin scope live) =="
mkdir -p "$NET/si-agent/inbox"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick.md" > "$NET/si-agent/inbox/${ms}-${sfx}.md"
echo "   kick seeded $NET/si-agent/inbox/${ms}-${sfx}.md (names no tokens — worker must invoke the skills)"

echo
echo "SPUN (skill-inheritance, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'si-agent' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): si-agent boots -> invokes the skills it INHERITED:"
echo "  • evalskill-project (PROJECT scope, repo .claude/skills)  -> writes repo/SKILL_PROJECT.txt = <project token>"
echo "  • evalpkg:evalskill-plugin (PLUGIN scope, --plugin-dir)   -> writes repo/SKILL_PLUGIN.txt  = <plugin token>"
echo "  A sentinel with the right secret token PROVES that scope was inherited (the token was only in the skill body)."
echo "GRADE:     $HERE/grade.sh \"$SB\""
echo "TEARDOWN:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
