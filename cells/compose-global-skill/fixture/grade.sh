#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for COMPOSE-GLOBAL-SKILL. Proves a GLOBAL (user-level ~/.claude/skills) skill still fires
# through a convoy compose — i.e. the compose does not SHADOW/BREAK global-skill discovery. Deterministic NO-SHADOW
# core (box-free) + a live headline (Nathan's READ-ONLY existing-skill approach: default config dir, real auth, no
# key; assert on a distinctive string from the skill's OWN body).
#
# CRITICAL ISOLATION: the eval only READS ~/.claude/skills — never writes it. This grader HARD-GATES that the real
# ~/.claude/skills is byte-identical before/after.
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
P="$SB/.probe"
SKILL="$(tr -d '\r\n' < "$SB/.stev/skill" 2>/dev/null)"
ASSERT="$(tr -d '\r\n' < "$SB/.stev/assert" 2>/dev/null)"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
[ -n "$SKILL" ] && echo "global skill under test (read-only): $SKILL  assert-string: $ASSERT" || echo "no supported global skill installed — live arm skips; NO-SHADOW carries it"
if grep -q 'CONVOY-MISSING' "$P/pty-env.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi

echo
echo "== NO-SHADOW (hard, deterministic) — the compose does not relocate/disable/scope-away global-skill discovery =="
if [ -f "$P/no-shadow.txt" ]; then
  grep -q '^env_sets_config_dir=no' "$P/no-shadow.txt" && ok "convoy pty.toml sets NO CLAUDE_CONFIG_DIR — the agent uses the DEFAULT config dir where the user's global skills live => discoverable" \
                                                        || no "convoy pty.toml SETS CLAUDE_CONFIG_DIR — relocates the config dir, shadowing the user's global skills"
  grep -q '^cmd_relocates_or_disables=no' "$P/no-shadow.txt" && ok "the launch command carries no --config-dir and no --disable-slash-commands (skills not relocated/disabled)" \
                                                             || no "the launch command relocates the config dir or disables skills"
  grep -q '^settings_touches_skills=no' "$P/no-shadow.txt" && ok "convoy settings.local.json is additive (hooks only) — touches NO skill key, cannot suppress global-skill discovery" \
                                                           || no "convoy settings.local.json touches a skill key — could suppress global skills"
else
  sk "no no-shadow.txt — run probe.sh"
fi

# --- live headline (read-only existing-skill; default config dir; real auth) -----------------------------------
has(){ local f="$1" want="$2"; [ -f "$f" ] || return 2; grep -qiF "$want" "$f" && return 0 || return 1; }

echo
echo "== GLOBAL SKILL FIRES (headline, rides the box) — the composed agent used a GLOBAL skill =="
if [ -z "$SKILL" ]; then
  sk "no supported global skill in ~/.claude/skills — live arm skips (portability); NO-SHADOW carries the proof"
else
  has "$SB/repo/GLOBAL_SKILL.txt" "$ASSERT"; r=$?
  if   [ $r = 0 ]; then ok "GLOBAL_SKILL.txt contains '$ASSERT' — a distinctive string from the $SKILL skill's body (never in the kick) => the GLOBAL skill LOADED + fired through the compose"
  elif [ $r = 2 ]; then sk "no GLOBAL_SKILL.txt — live arm not exercised (run spin.sh); NO-SHADOW carries the deterministic proof"
  else                  no "GLOBAL_SKILL.txt present but lacks '$ASSERT' (got: $(tr -d '\n' < "$SB/repo/GLOBAL_SKILL.txt" | head -c 60)) — the global skill did NOT fire (a skill-less agent gives the raw answer)"; fi
fi

echo
echo "== NEGATIVE CONTROL (headline) — an unrelated-question agent must NOT emit the skill's string =="
CTL="$SB/control/GLOBAL_SKILL.txt"
if [ -z "$SKILL" ] || [ ! -f "$SB/repo/GLOBAL_SKILL.txt" ]; then
  sk "control not evaluated (live arm not exercised)"
else
  has "$CTL" "$ASSERT"; r=$?
  if [ $r = 0 ]; then no "CONTROL emitted '$ASSERT' on an UNRELATED question — the string is ambient, not skill-driven (the positive proof would be weak)"
  else               ok "control did not emit '$ASSERT' (it answered the unrelated question) — the positive answer was skill-driven, not ambient"; fi
fi

echo
echo "== ISOLATION (hard gate — the eval only READ ~/.claude/skills; no session leak) =="
ls -1 "${HOME:-/nonexistent}/.claude/skills" 2>/dev/null | sort > "$P/real-skills-after.txt" || true
if diff -q "$P/real-skills-before.txt" "$P/real-skills-after.txt" >/dev/null 2>&1; then
  ok "real ~/.claude/skills is UNCHANGED (before == after) — the eval only READ the user's global skills"
else
  no "real ~/.claude/skills CHANGED — the eval wrote the user's global skills:"; diff "$P/real-skills-before.txt" "$P/real-skills-after.txt" | sed 's/^/        /'
fi
leak_pty="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE 'gsw|gsnc' || true)"
[ "${leak_pty:-0}" = 0 ] && ok "no gsw/gsnc session in the operator's global pty root (isolated net only)" \
                         || no "LEAK: gsw/gsnc session in the global pty root (pty=$leak_pty)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> compose-global-skill: NO hard failures. The convoy compose does NOT shadow global-skill discovery"
  echo "    (NO-SHADOW core), and — read-only, default config dir — a composed agent fired a real GLOBAL skill"
  echo "    ($SKILL -> '$ASSERT'), with the user's ~/.claude/skills left untouched."
else
  echo "==> compose-global-skill: $fail HARD FAILURE(S) — see [FAIL] rows."
fi
[ "$fail" -eq 0 ]
