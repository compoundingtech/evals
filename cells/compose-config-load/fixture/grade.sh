#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for COMPOSE-CONFIG-LOAD. Proves a repo's OWN CLAUDE.md + skills still LOAD + WORK after a
# convoy agent is composed into it. Deterministic gates (from probe.sh) + a live headline (sentinels from spin.sh).
# Never a self-report: the SECRET lives only in the repo CLAUDE.md and the GREET token only in the skill body
# (never in the kick), each per-run nonce'd — so a sentinel bearing the right token can ONLY come from actually
# loading that file through the compose.
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/ccl}"
P="$SB/.probe"; REPO="$SB/repo"
SECRET="$(tr -d '\r\n' < "$SB/.stev/token-secret" 2>/dev/null)"
GREET="$(tr -d '\r\n' < "$SB/.stev/token-greet" 2>/dev/null)"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
[ -n "$SECRET" ] && [ -n "$GREET" ] || { echo "no per-run tokens — did setup-sandbox run?"; exit 1; }
echo "tokens this run: secret=$SECRET  greet=$GREET"

echo
echo "== CLAUDE.md UNTOUCHED (hard, deterministic) — convoy did not clobber the repo's own CLAUDE.md =="
if [ -d "$P" ] && ! grep -q 'CONVOY-MISSING' "$P/claude-md-after.sha" 2>/dev/null; then
  b="$(cat "$P/claude-md-before.sha" 2>/dev/null)"; a="$(cat "$P/claude-md-after.sha" 2>/dev/null)"
  [ -n "$a" ] && [ "$b" = "$a" ] && ok "tracked CLAUDE.md is byte-identical after convoy add ($a) — not clobbered" \
                                 || no "tracked CLAUDE.md CHANGED after convoy add (before=$b after=$a) — the compose overwrote it"
else
  sk "no probe artifacts (or convoy missing) — run probe.sh; CLAUDE.md-untouched unproven this run"
fi

echo
echo "== CLAUDE.local.md ADDITIVE (hard, deterministic) — convoy layers alongside, does not replace =="
if [ -f "$P/claude-local.md" ] && ! grep -q '(no CLAUDE.local.md)' "$P/claude-local.md" 2>/dev/null; then
  ok "convoy wrote CLAUDE.local.md (additive layer)"
  grep -qE '^@(PERSONA|DING-BUS)\.md' "$P/claude-local.md" && ok "CLAUDE.local.md @-imports the convoy persona/ding (the layering mechanism) — CC loads it ALONGSIDE the repo CLAUDE.md" \
                                                            || wn "CLAUDE.local.md present but no @-imports found — eyeball $P/claude-local.md"
  grep -q '^both_files_coexist=yes' "$P/tokens-present.txt" 2>/dev/null && ok "CLAUDE.md and CLAUDE.local.md COEXIST — the repo instruction is layered, not replaced" \
                                                                        || no "the repo CLAUDE.md and CLAUDE.local.md do not both exist — layering broken"
else
  sk "no CLAUDE.local.md captured — run probe.sh"
fi

echo
echo "== CONFIG INTACT (hard, deterministic) — the secret + skill token survive the compose, tracked =="
if [ -f "$P/tokens-present.txt" ]; then
  grep -q '^secret_in_claude_md=yes' "$P/tokens-present.txt" && ok "the SECRET token is still in the repo CLAUDE.md after the compose" \
                                                             || no "the SECRET token is GONE from CLAUDE.md after the compose"
  grep -q '^greet_in_skill=yes'      "$P/tokens-present.txt" && ok "the GREET token is still in the project skill SKILL.md after the compose" \
                                                             || no "the GREET token is GONE from the skill after the compose"
  grep -q '^config_tracked=yes'      "$P/tokens-present.txt" && ok "CLAUDE.md + skill SKILL.md remain TRACKED (convoy did not untrack the repo's config)" \
                                                             || no "the repo config is no longer tracked after the compose"
else
  sk "no tokens-present.txt — run probe.sh"
fi

# --- live headline: the agent actually LOADED + FOLLOWED the config through the compose --------------------------
sent(){ local f="$REPO/$1" want="$2"; [ -f "$f" ] || return 2; [ "$(tr -d '[:space:]' < "$f")" = "$want" ] && return 0 || return 1; }

echo
echo "== CLAUDE.md LOADS (headline, rides the box) — the agent produced the secret from its repo CLAUDE.md =="
sent "SECRET.txt" "$SECRET"; r=$?
if   [ $r = 0 ]; then ok "SECRET.txt carries the exact per-run secret — the repo CLAUDE.md LOADED + was followed through the compose"
elif [ $r = 2 ]; then wn "no SECRET.txt — live run not exercised (run spin.sh); the deterministic gates carry the loading-path proof"
else                  no "SECRET.txt present but token mismatch — the agent did not get the secret from CLAUDE.md (clobbered/not loaded)"; fi

echo
echo "== SKILL LOADS (headline, rides the box) — the agent used its project greet skill =="
sent "GREET.txt" "$GREET"; r=$?
if   [ $r = 0 ]; then ok "GREET.txt carries the exact per-run greet token — the project skill LOADED + fired through the compose"
elif [ $r = 2 ]; then wn "no GREET.txt — live run not exercised (run spin.sh); deterministic gates carry the proof"
else                  no "GREET.txt present but token mismatch — the greet skill was not actually invoked"; fi

echo
echo "== ISOLATION (hard gate) — the compose leaked no session into the operator's global pty/convoy root =="
leak_pty="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE 'ccl|cclp' || true)"
leak_conv="$(convoy ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '\bccl\b|cclp' || true)"
if [ "${leak_pty:-0}" = 0 ] && [ "${leak_conv:-0}" = 0 ]; then ok "no ccl/cclp session in the global/prod pty or convoy root (isolated nets only)"
else no "LEAK: ccl/cclp appears in the global pty/convoy root (pty=$leak_pty convoy=$leak_conv)"; fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> compose-config-load: NO hard failures. A repo's OWN CLAUDE.md + skills survive + load through the convoy"
  echo "    compose (CLAUDE.md untouched, CLAUDE.local.md additive, config intact); the live headline proves the agent"
  echo "    followed both (SECRET.txt + GREET.txt bear the per-run tokens). Nathan's guarantee: composed config still works."
else
  echo "==> compose-config-load: $fail HARD FAILURE(S) — see [FAIL] rows (a clobbered CLAUDE.md or an unloaded skill)."
fi
[ "$fail" -eq 0 ]
