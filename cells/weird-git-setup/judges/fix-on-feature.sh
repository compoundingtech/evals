#!/usr/bin/env bash
# THE DISCRIMINATOR: the fix is committed ON `feature` (ahead of the seed) AND authored by the worktree's pinned
# author (wt-feature@) — proving the agent resolved the worktree layout and committed HERE, not nowhere useful.
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"; WT="$SB/wt/feature"; BARE="$SB/canonical.git"
SEED="$(git -C "$BARE" rev-list --max-parents=0 main 2>/dev/null | tail -1)"
ahead="$(git -C "$WT" rev-list --count "$SEED"..HEAD 2>/dev/null || echo 0)"
[ "${ahead:-0}" -ge 1 ] || { echo "FAIL: no commit on 'feature' beyond the seed — nothing landed on this branch"; exit 1; }
ae="$(git -C "$WT" show -s --format='%ae' HEAD 2>/dev/null)"
case "$ae" in
  wt-feature@*) echo "PASS: fix committed on 'feature' ($ahead beyond seed), authored by the worktree's pinned author ($ae)"; exit 0 ;;
  *seed@*)      echo "FAIL: feature tip is still the seed commit (no agent work landed on this branch)"; exit 1 ;;
  *)            echo "FAIL: feature tip authored by '$ae' (expected wt-feature@…) — wrong/absent author"; exit 1 ;;
esac
