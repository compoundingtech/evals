#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-WORKTREE-CUTTING. Asserts `convoy init --megarepo` + `convoy add` cut a REAL
# linked git worktree off the megarepo (redesign #4b, convoy #59). Never a self-report — grades the on-disk shape
# probe.sh captured. Mutation-valid: a plain clone (`.git` a dir) or a missing worktree FAILS; a self-test proves
# the presence check is non-vacuous.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/wct}"
P="$SB/.probe"; id="wtw"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
g(){ grep -q "^$1" "$P/shape.txt"; }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'CONVOY-MISSING' "$P/shape.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }

echo
echo "== WORKTREE CUT (hard gate) — convoy add cut <net>/worktrees/<id>/ off the megarepo =="
g "wt_exists=yes" && ok "<net>/worktrees/$id/ exists (convoy add placed the workspace there)" \
                  || no "<net>/worktrees/$id/ MISSING — convoy add did not cut a worktree (megarepo model not landed / no megarepo recorded)"

echo
echo "== LINKED WORKTREE, NOT A CLONE (hard gate) — .git is a FILE pointing into the megarepo =="
g "git_is_file=yes" && ok "the workspace .git is a FILE (a linked-worktree marker), not a directory (a clone)" \
                    || no "the workspace .git is NOT a file — it is a clone/plain repo, not a linked worktree off the megarepo"
g "gitdir_into_mega=yes" && ok "the .git gitdir points into <megarepo>/.git/worktrees/$id (shares the megarepo object store)" \
                         || no "the .git gitdir does NOT point into the megarepo — not a real worktree of it"

echo
echo "== BRANCH (hard gate) — the worktree is on branch convoy/<id> =="
br="$(sed -n 's/^branch=//p' "$P/shape.txt")"
[ "$br" = "convoy/$id" ] && ok "worktree is on branch convoy/$id (its own branch, not the megarepo's)" \
                         || no "worktree branch is '$br', expected convoy/$id"

echo
echo "== REAL WORKTREE OF THE MEGAREPO (hard gate) — the megarepo git-worktree-list includes it =="
g "in_worktree_list=yes" && ok "the megarepo's git worktree list includes <net>/worktrees/$id [convoy/$id] — it is genuinely a worktree OF the megarepo" \
                         || { no "the megarepo does NOT list this worktree — it is not a real linked worktree"; echo "     worktree list:"; sed 's/^/       /' "$P/worktree-list.txt" 2>/dev/null; }

echo
echo "== NO POLLUTION (hard gate) — both the worktree AND the megarepo stay clean =="
g "wt_clean=yes"   && ok "the worktree working tree is clean (git status --porcelain empty — convoy overlay is git-excluded)" \
                   || no "the worktree is DIRTY after convoy add — pollution"
g "mega_clean=yes" && ok "the MEGAREPO working tree is UNTOUCHED (clean) — cutting a worktree did not dirty the megarepo" \
                   || no "the megarepo is DIRTY — cutting the worktree leaked into the megarepo working tree"

echo
echo "== MUTATION-VALID (hard gate) — the presence check is non-vacuous =="
g "selftest_bogus_absent=yes" && ok "a bogus worktree id reads ABSENT — the presence check genuinely tests presence" \
                              || no "self-test failed — the presence check may be vacuous"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-worktree-cutting: PASS — convoy cuts a real linked git worktree off the megarepo (worktrees/$id,"
  echo "    .git-is-a-file into the megarepo, branch convoy/$id, both trees clean). The structural fix for pollution."
else
  echo "==> convoy-worktree-cutting: FAIL — the megarepo worktree model does not match the target (redesign #4b / convoy #59)."
fi
[ "$fail" -eq 0 ]
