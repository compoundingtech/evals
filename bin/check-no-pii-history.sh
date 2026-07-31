#!/usr/bin/env bash
# Mutation-check check-no-pii.sh against a path committed and then deleted from a published _git fixture.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="${1:-$repo_root/bin/check-no-pii.sh}"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

forbidden="HISTORY_PRIVATE_"'SENTINEL'

commit_fixture_tree() {
  local target="$1" message="$2" tree parent commit ref
  tree="$(git -C "$target" write-tree)"
  parent="$(git -C "$target" rev-parse --verify HEAD 2>/dev/null || true)"
  if [ -n "$parent" ]; then
    commit="$(
      printf '%s\n' "$message" |
        GIT_AUTHOR_NAME="Fixture Author" GIT_AUTHOR_EMAIL="fixture@example.invalid" \
        GIT_COMMITTER_NAME="Fixture Author" GIT_COMMITTER_EMAIL="fixture@example.invalid" \
        GIT_AUTHOR_DATE="2026-07-30T00:00:00Z" GIT_COMMITTER_DATE="2026-07-30T00:00:00Z" \
        git -C "$target" commit-tree "$tree" -p "$parent"
    )"
  else
    commit="$(
      printf '%s\n' "$message" |
        GIT_AUTHOR_NAME="Fixture Author" GIT_AUTHOR_EMAIL="fixture@example.invalid" \
        GIT_COMMITTER_NAME="Fixture Author" GIT_COMMITTER_EMAIL="fixture@example.invalid" \
        GIT_AUTHOR_DATE="2026-07-30T00:00:00Z" GIT_COMMITTER_DATE="2026-07-30T00:00:00Z" \
        git -C "$target" commit-tree "$tree"
    )"
  fi
  ref="$(git -C "$target" symbolic-ref HEAD)"
  git -C "$target" update-ref "$ref" "$commit"
}

make_fixture() {
  local target="$1" content="$2"
  mkdir -p "$target"
  git -C "$target" init -q
  printf '%s\n' "portable fixture" >"$target/README.md"
  printf '%s\n' "$content" >"$target/removed.txt"
  git -C "$target" add README.md removed.txt
  # This is scanner input construction, not an agent-authored commit lifecycle. Plumbing keeps host commit
  # hooks and their private provenance trailers outside the synthetic history under test.
  commit_fixture_tree "$target" "seed"
  rm -f -- "$target/removed.txt"
  git -C "$target" add -u
  commit_fixture_tree "$target" "remove obsolete fixture file"
  mv -- "$target/.git" "$target/_git"
}

make_fixture "$scratch/dirty" "$forbidden"
make_fixture "$scratch/clean" "portable historical content"

# Guard the mutation itself: the dirty sentinel must be absent from the worktree but recoverable from a
# reachable historical blob, or this would be a test that always passes.
[ ! -e "$scratch/dirty/removed.txt" ] || {
  echo "FAIL: dirty history mutation left the planted file in the worktree" >&2
  exit 1
}
git --git-dir="$scratch/dirty/_git" grep -q "$forbidden" "$(git --git-dir="$scratch/dirty/_git" rev-list --all | tail -1)" || {
  echo "FAIL: dirty history mutation did not create a reachable historical match" >&2
  exit 1
}

dirty_output="$scratch/dirty.out"
if PII_TOKENS="$forbidden" bash "$checker" "$scratch/dirty" >"$dirty_output" 2>&1; then
  echo "FAIL: check-no-pii accepted a forbidden token committed and then deleted from _git history" >&2
  cat "$dirty_output" >&2
  exit 1
fi
grep -Fq '_git@' "$dirty_output" || {
  echo "FAIL: dirty control failed without identifying a reachable _git blob" >&2
  cat "$dirty_output" >&2
  exit 1
}

clean_output="$scratch/clean.out"
PII_TOKENS="$forbidden" bash "$checker" "$scratch/clean" >"$clean_output" 2>&1 || {
  echo "FAIL: check-no-pii rejected the clean reachable-history control" >&2
  cat "$clean_output" >&2
  exit 1
}

echo "PASS: check-no-pii rejects committed-then-deleted fixture content and accepts a clean reachable history"
