#!/usr/bin/env bash
# Spin weird-git-setup: convoy-init the isolated bus, seed the task into the worker's inbox, and convoy-add the
# worker INTO wt/feature (the worktree — the launch case). SINGLE agent: it must detect its worktree git context,
# fix the planted bug, keep the suite green, and commit on the FEATURE branch — 0 rescues. Run AFTER setup-sandbox.sh.
#   ./spin.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/weird-git-setup
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it) + convoy on PATH.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"                # stev_seed_kick (deliver the kick over the real bus)
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/weird-git-setup}"
[ -d "$SB/wt/feature" ] || "$HERE/setup-sandbox.sh" "$SB"
STR="$SB/st-root"; id="wg-dev"

echo "== convoy init the isolated bus ($STR) =="
mkdir -p "$STR"                       # convoy init requires the dir to exist
convoy init "$STR" >/dev/null

echo "== compose the worker persona (NO worktree hints — the agent must figure the git setup out) =="
"$HERE/compose-persona.sh" "$SB" >/dev/null
persona="$SB/personas-local/$id.md"

echo "== capture the PRE layout probe (held-out worktree ground truth) =="
"$HERE/layout-probe.sh" "$SB" pre >/dev/null

echo "== convoy add the worker INTO wt/feature (the worktree launch case) + host it =="
# `--yes` is gone from convoy add; --force makes the declare idempotent. `convoy add` only DECLARES, so
# reconcile once (convoy up --once) to actually spawn the session — without it the agent never launches.
( cd "$SB/wt/feature" && convoy add worker --identity "$id" --network "$STR" --dir "$SB/wt/feature" --persona "$persona" --force )
convoy up --once "$STR" >/dev/null

echo "== deliver the hermetic task to $id over the REAL bus (once it registers) =="
# convoy runs the bus at $STR/smalltalk/<host>.$id; the pre-convoy $STR/$id/inbox file-drop landed where
# nobody watched. stev_seed_kick waits for $id to register, then st-sends the kick (from morgan, per its from:).
stev_seed_kick "$STR" "$id" "$HERE/kick-worktree.md" >/dev/null
echo "   delivered the task to $id over $STR/smalltalk"

echo
echo "SPUN. worker '$id' launched inside $SB/wt/feature (a LINKED WORKTREE of $SB/canonical.git; .git is a file)."
echo "OBSERVE (ST_ROOT=$STR): the worker drains the kick -> figures out its worktree context -> fixes"
echo "  src/clamp.js (above-range -> hi) + adds a regression test -> keeps 'node --test' green -> COMMITS ON THE"
echo "  'feature' BRANCH (not main, not the bare repo, not the sibling wt/main) -> reports done."
echo "GRADE when done:  fixture/grade.sh \"$SB\""
echo "TEARDOWN:  convoy down \"$STR\" --force   (down is the only path that kills sessions)"
