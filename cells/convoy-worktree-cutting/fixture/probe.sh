#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-worktree-cutting) — DETERMINISTIC, box-free, no LLM. Proves `convoy init --megarepo <path>` +
# `convoy add <id>` cut a REAL linked git worktree off the megarepo into <net>/worktrees/<id> (redesign #4b, doc
# 4aab4f1). Captures the ground truth grade.sh asserts:
#   • <net>/worktrees/<id>/ exists (convoy add put the workspace there)
#   • its .git is a FILE (a linked worktree marker: `gitdir: <megarepo>/.git/worktrees/<id>`), NOT a dir (a clone)
#   • it is on branch convoy/<id>
#   • the MEGAREPO's `git worktree list` includes it (it is genuinely a worktree OF the megarepo, not a copy)
#   • BOTH the worktree AND the megarepo are CLEAN (no pollution of either working tree)
#
# Live @ convoy #59 (36d5cf8). Isolated short paths; torn down; never touches the live convoy.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/wct}"
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
mega="$SB/mega"; NET="$SB/net"; id="wtw"

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/shape.txt"; exit 0
fi

# Record WHICH convoy this ran against (worktree-cutting is convoy-version-dependent — #4b/#59).
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (ahead of committed sha)"
} > "$P/convoy-version.txt" 2>/dev/null || true

# The megarepo: a real git repo with a commit (a worktree needs a HEAD to branch from).
git -C "$SB" init -q mega 2>/dev/null || { mkdir -p "$mega"; git -C "$mega" init -q; }
git -C "$mega" config user.name  "megarepo"; git -C "$mega" config user.email "megarepo@eval.local"
printf '# megarepo\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m "seed megarepo"
printf '# worktree worker %s\nYou are %s.\n' "$id" "$id" > "$P/persona.md"
export ST_ROOT="$NET"; export PTY_ROOT="$NET/pty"
trap 'stev_convoy_teardown "$NET" >/dev/null 2>&1 || true' EXIT INT TERM

echo "== convoy init --megarepo + convoy add (cuts a worktree off the megarepo) =="
convoy init "$NET" --megarepo "$mega" > "$P/init.out" 2>&1
convoy add worker --identity "$id" --network "$NET" --persona "$P/persona.md" --harness claude > "$P/add.out" 2>&1
echo "   add rc=$?"

echo "== capture the worktree shape =="
wt="$NET/worktrees/$id"
gitfile="$wt/.git"
megareal="$(cd "$mega" 2>/dev/null && pwd -P)"
{
  [ -d "$wt" ] && echo "wt_exists=yes" || echo "wt_exists=no"
  # .git must be a FILE (linked worktree), and point into <megarepo>/.git/worktrees/<id>
  if [ -f "$gitfile" ]; then
    gd="$(sed -n 's/^gitdir: //p' "$gitfile" 2>/dev/null)"
    echo "git_is_file=yes"
    case "$gd" in *"/.git/worktrees/$id") echo "gitdir_into_mega=yes";; *) echo "gitdir_into_mega=no ($gd)";; esac
  elif [ -d "$gitfile" ]; then echo "git_is_file=no (it is a DIR — a clone, not a linked worktree)"; echo "gitdir_into_mega=no"
  else echo "git_is_file=no (absent)"; echo "gitdir_into_mega=no"; fi
  echo "branch=$(git -C "$wt" branch --show-current 2>/dev/null)"
  # the megarepo must list this worktree (it is a real worktree OF the megarepo)
  git -C "$mega" worktree list 2>/dev/null | grep -qE "worktrees/$id[[:space:]].*\[convoy/$id\]" && echo "in_worktree_list=yes" || echo "in_worktree_list=no"
  # neither working tree polluted
  [ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ] && echo "wt_clean=yes" || echo "wt_clean=no"
  [ -z "$(git -C "$mega" status --porcelain 2>/dev/null)" ] && echo "mega_clean=yes" || echo "mega_clean=no"
  # SELF-TEST (mutation-validity): a bogus worktree id must be absent (the presence check is non-vacuous).
  [ -d "$NET/worktrees/__nope__" ] && echo "selftest_bogus_absent=no" || echo "selftest_bogus_absent=yes"
} > "$P/shape.txt"
echo "megarepo_real=$megareal" >> "$P/shape.txt"
git -C "$mega" worktree list > "$P/worktree-list.txt" 2>&1 || true
sed 's/^/     /' "$P/shape.txt"

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
