#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (compose-config-load) — DETERMINISTIC, box-free. Composes an agent into a COPY of the repo (so it never
# disturbs the live spin.sh repo) and captures the ground truth that the repo's own config SURVIVES the compose:
#   1. claude-md-{before,after}.sha — the tracked CLAUDE.md must be BYTE-IDENTICAL after `convoy add` (UNTOUCHED,
#      not clobbered).
#   2. claude-local.md              — convoy's ADDITIVE CLAUDE.local.md (it @-imports PERSONA.md + DING-BUS.md;
#      CC loads it ALONGSIDE the repo's CLAUDE.md, so both coexist — the repo instruction is not replaced).
#   3. tokens-present.txt           — the SECRET token still in CLAUDE.md AND the GREET token still in the skill
#      SKILL.md after the compose (the config the agent must load is intact + tracked).
# This proves the LOADING PATH is real without needing the model to reason; spin.sh's live headline proves the
# agent actually FOLLOWS it. Isolated net + scoped PTY_ROOT; torn down.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/ccl}"
[ -d "$SB/repo/.git" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }
SECRET="$(tr -d '\r\n' < "$SB/.stev/token-secret" 2>/dev/null)"
GREET="$(tr -d '\r\n' < "$SB/.stev/token-greet" 2>/dev/null)"
P="$SB/.probe"; rm -rf "$P"; mkdir -p "$P"

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/claude-md-after.sha"; exit 0
fi

# Compose into a COPY so the live spin repo stays pristine.
cp -R "$SB/repo" "$P/repo"
pr="$P/repo"; NET="$SB/pnet"; id="cclp"
git -C "$pr" hash-object CLAUDE.md > "$P/claude-md-before.sha"
printf '# probe worker %s\nYou are %s.\n' "$id" "$id" > "$P/persona.md"
export ST_ROOT="$NET"; export PTY_ROOT="$NET/pty"
trap 'stev_convoy_teardown "$NET" >/dev/null 2>&1 || true' EXIT INT TERM

echo "== convoy add into the repo copy (isolated net) =="
stev_convoy_init "$NET" >/dev/null 2>&1 || true
convoy add worker --identity "$id" --network "$NET" --dir "$pr" --persona "$P/persona.md" --harness claude >"$P/add.out" 2>&1
echo "   add rc=$?"

echo "== capture: CLAUDE.md untouched? CLAUDE.local.md additive? tokens intact? =="
git -C "$pr" hash-object CLAUDE.md > "$P/claude-md-after.sha"
[ -f "$pr/CLAUDE.local.md" ] && cp "$pr/CLAUDE.local.md" "$P/claude-local.md" || printf '(no CLAUDE.local.md)\n' > "$P/claude-local.md"
{
  grep -qF "$SECRET" "$pr/CLAUDE.md"                       && echo "secret_in_claude_md=yes"   || echo "secret_in_claude_md=no"
  grep -qF "$GREET"  "$pr/.claude/skills/greet/SKILL.md"   && echo "greet_in_skill=yes"         || echo "greet_in_skill=no"
  { [ -f "$pr/CLAUDE.md" ] && [ -f "$pr/CLAUDE.local.md" ]; } && echo "both_files_coexist=yes"  || echo "both_files_coexist=no"
  git -C "$pr" ls-files --error-unmatch CLAUDE.md .claude/skills/greet/SKILL.md >/dev/null 2>&1 && echo "config_tracked=yes" || echo "config_tracked=no"
} > "$P/tokens-present.txt"
sed 's/^/     /' "$P/tokens-present.txt"

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
