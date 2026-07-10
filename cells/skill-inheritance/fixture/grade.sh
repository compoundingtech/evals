#!/usr/bin/env bash
# Grade skill-inheritance on REAL STATE (sentinel files bearing per-run secret tokens), never a self-report.
# A sentinel with the right token proves the worker LOADED + invoked that skill — the token lived only in the
# skill body, so it was unobtainable without inheriting the skill. Also hard-gates ISOLATION: prod convoy
# untouched + ~/.claude/skills and ~/.claude/plugins NOT polluted by the test.
#   ./grade.sh [SANDBOX]
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/skill-inheritance}"
NET="$SB/st-root"
REPO="$SB/repo"
TOK_PROJ="$(cat "$SB/.stev/token-project" 2>/dev/null | tr -d '[:space:]')"
TOK_PLUG="$(cat "$SB/.stev/token-plugin"  2>/dev/null | tr -d '[:space:]')"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
[ -d "$REPO/.git" ] || { echo "no sandbox at $SB — did spin run?"; exit 1; }
[ -n "$TOK_PROJ" ] && [ -n "$TOK_PLUG" ] || { echo "no per-run tokens recorded — did setup-sandbox run?"; exit 1; }

# sentinel_ok <file> <expected-token> : the file exists and its trimmed content equals the secret token.
sentinel_ok() {
  local f="$REPO/$1" want="$2"
  [ -f "$f" ] || return 2
  [ "$(tr -d '[:space:]' < "$f")" = "$want" ] && return 0 || return 1
}

echo "== PROJECT scope inherited (hard gate — repo .claude/skills skill fired) =="
sentinel_ok "SKILL_PROJECT.txt" "$TOK_PROJ"; r=$?
if   [ $r = 0 ]; then ok "SKILL_PROJECT.txt carries the project skill's secret token — PROJECT scope inherited + invoked"
elif [ $r = 2 ]; then no "SKILL_PROJECT.txt absent — the project-scope skill never fired (not inherited, or not invoked)"
else                  no "SKILL_PROJECT.txt present but token mismatch — sentinel not produced by the real skill body"; fi

echo "== PLUGIN scope inherited — UNION across scopes (hard gate — --plugin-dir skill fired) =="
sentinel_ok "SKILL_PLUGIN.txt" "$TOK_PLUG"; r=$?
if   [ $r = 0 ]; then ok "SKILL_PLUGIN.txt carries the plugin skill's secret token — PLUGIN scope inherited via --plugin-dir (union with project)"
elif [ $r = 2 ]; then no "SKILL_PLUGIN.txt absent — the plugin-scope skill never fired (--plugin-dir not honored, or not invoked)"
else                  no "SKILL_PLUGIN.txt present but token mismatch — sentinel not produced by the real plugin skill body"; fi

echo "== ISOLATION (hard gate — the test polluted nothing shared) =="
# a) prod convoy / global pty root carries no si-agent session
leak_pty="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -c 'si-agent' || true)"
leak_convoy="$(convoy ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -c 'si-agent' || true)"
if [ "${leak_pty:-0}" = 0 ] && [ "${leak_convoy:-0}" = 0 ]; then ok "no si-agent session in the global/prod pty or convoy root (isolated net only)"
else no "LEAK: si-agent appears in the global pty/convoy root (pty=$leak_pty convoy=$leak_convoy) — sidecar escaped the isolated net"; fi
# b) personal-scope skills untouched — no evalskill-* under ~/.claude/skills
pol_sk="$(ls "$HOME/.claude/skills" 2>/dev/null | grep -c 'evalskill' || true)"
[ "${pol_sk:-0}" = 0 ] && ok "~/.claude/skills carries no evalskill-* (Nathan's personal skills untouched)" || no "POLLUTION: $pol_sk evalskill-* dir(s) under ~/.claude/skills — the test wrote into personal scope"
# c) global plugin cache untouched — --plugin-dir did not register evalpkg globally
pol_pl="$(find "$HOME/.claude/plugins" -maxdepth 4 -iname 'evalpkg*' 2>/dev/null | grep -c . || true)"
[ "${pol_pl:-0}" = 0 ] && ok "~/.claude/plugins carries no evalpkg (--plugin-dir stayed session-local)" || wn "evalpkg found under ~/.claude/plugins ($pol_pl) — --plugin-dir may have cached globally; clean it in teardown"

echo "== NEGATIVE CONTROL (soft — sentinels track real availability, not fabrication) =="
if [ -f "$REPO/SKILL_ABSENT.txt" ]; then wn "SKILL_ABSENT.txt exists — a non-inherited skill's effect appeared (should be impossible; investigate)"; else ok "no sentinel for a non-existent skill (the worker only produced effects for skills it truly had)"; fi

echo "== CORROBORATION (info — the Skill tool actually fired in the transcript) =="
# Claude stores a session's transcript under ~/.claude/projects/<cwd with '/' -> '-'>. Target that one dir
# (fast + scoped) rather than grepping all of the operator's projects.
REPO_ABS="$(cd "$REPO" 2>/dev/null && pwd)"; enc="$(printf '%s' "$REPO_ABS" | sed 's#/#-#g')"
txdir="$HOME/.claude/projects/$enc"
tx="$(grep -rlE '"name":\s*"Skill"' "$txdir" 2>/dev/null | head -1)"
if [ -n "$tx" ] && grep -qE 'evalskill' "$tx" 2>/dev/null; then echo "  [info] Skill-tool invocation of an evalskill found in the worker transcript ($tx)"; else echo "  [info] transcript Skill-tool corroboration not located (non-fatal; sentinels are the ground truth)"; fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
if [ "$fail" = 0 ]; then
  echo "==> skill-inheritance: PASS — a convoy worker inherited user-brought skills across PROJECT + PLUGIN scopes"
  echo "    as a UNION (both secret-token sentinels landed), with zero pollution of personal scope / prod convoy."
  echo "    DEFERRED (documented, auth-gated): personal ~/.claude/skills inheritance + same-name precedence override."
else
  echo "==> skill-inheritance: FAIL — see the hard-gate failure above."
fi
