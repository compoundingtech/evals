#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CLEAN-COMPOSE. Asserts convoy composed an agent into the repo WITHOUT polluting it:
# `git status --porcelain` in the repo must be EMPTY after `convoy add`. Mutation-valid: a repo left dirty MUST
# fail (proven by the synthetic-dirt probe). Never a self-report — grades the real repo state probe.sh captured.
#
# Regression guard: convoy USED to leak `pty.toml` + `.claude/settings.local.json` into the working tree. convoy
# #51 (a609204, "clean worktree") started excluding the rig files (PERSONA.md/DING-BUS.md/CLAUDE.local.md) but
# MISSED two; convoy #53 completes it — adds `pty.toml` + `.claude/settings.local.json` to the repo's own
# .git/info/exclude (host-independent, not relying on any global ignore). With all 5 excluded this cell is GREEN.
# It is the DURABLE GUARD (the exact regression class #53 fixes: a self-exclude-at-write-site miss): it FAILS the
# moment a convoy-authored file stops self-excluding, and can never silently pass (the mutation arm has teeth).
#   ./grade.sh [SANDBOX]
# Exit 0 = clean compose (no hard failures).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cc}"
P="$SB/.probe"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }

if grep -q 'CONVOY-MISSING' "$P/porcelain.txt" 2>/dev/null; then
  sk "convoy not available — clean-compose could not run"; echo "SCORE: 0/0 (skipped)"; exit 0
fi

echo "== CLEAN-COMPOSE (hard gate) — git status --porcelain EMPTY after convoy add (no repo pollution) =="
if [ ! -s "$P/porcelain.txt" ]; then
  ok "git status --porcelain is EMPTY — convoy composed into the repo without polluting the working tree"
else
  no "convoy POLLUTED the repo — git status --porcelain is non-empty:"
  sed 's/^/        /' "$P/porcelain.txt"
  leaked="$(awk '{print $2}' "$P/porcelain.txt" | tr '\n' ' ')"
  echo "        leaked (not excluded): $leaked"
  case "$leaked" in
    *pty.toml*|*settings.local.json*) echo "        ^ the KNOWN convoy .git/info/exclude gap — this cell is RED until convoy excludes these (then GREEN)";;
  esac
fi

echo "== MUTATION-VALID (hard gate) — a dirty repo MUST fail (the porcelain gate has teeth) =="
if grep -q '^mutation_detected=yes' "$P/mutation.txt" 2>/dev/null; then
  ok "planted synthetic dirt WAS detected by git status --porcelain — the CLEAN-COMPOSE gate is non-vacuous"
else
  no "planted dirt was NOT detected — the porcelain gate is vacuous (a dirty repo could pass); FIX the probe"
fi

echo "== CONVOY VERSION (info, reproducibility) — the exclude coverage is convoy-version-dependent =="
if [ -s "$P/convoy-version.txt" ]; then
  sed 's/^/     /' "$P/convoy-version.txt"
  grep -q 'convoy_git_sha=c9a5dcb' "$P/convoy-version.txt" && echo "     ^ this IS the #53 merge (c9a5dcb) — GREEN expected" \
                                                            || echo "     ^ if this convoy predates #53 (c9a5dcb), a ?? pty.toml leak is EXPECTED (the cell correctly goes RED)"
else
  echo "     (convoy version not captured)"
fi

echo "== CONTEXT (info) — everything convoy wrote, and what it already excludes =="
if [ -s "$P/written.txt" ]; then
  echo "  convoy-created files (?? = leaks into porcelain, !! = already excluded/ignored):"
  grep -vE 'CLAUDE.md|SKILL.md' "$P/written.txt" | sed 's/^/     /'
else
  echo "  (no written.txt captured)"
fi

echo "== ISOLATION (hard gate) — the compose leaked no session into the operator's global pty/convoy root =="
leak_pty="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -c 'ccw' || true)"
leak_conv="$(convoy ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -c 'ccw' || true)"
if [ "${leak_pty:-0}" = 0 ] && [ "${leak_conv:-0}" = 0 ]; then
  ok "no ccw session in the global/prod pty or convoy root (isolated net only)"
else
  no "LEAK: ccw appears in the global pty/convoy root (pty=$leak_pty convoy=$leak_conv)"
fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> clean-compose: PASS — convoy composes into a repo with ZERO working-tree pollution, and the gate is"
  echo "    mutation-valid (a dirty repo fails). Nathan's guarantee: we can work in convoy without polluting the repo."
else
  echo "==> clean-compose: FAIL — convoy REGRESSED the clean-worktree fix (#51 + #53): a convoy-authored file"
  echo "    (e.g. pty.toml / .claude/settings.local.json) is no longer in .git/info/exclude. This guard caught it."
fi
[ "$fail" -eq 0 ]
