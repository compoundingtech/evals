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

make_fixture() {
  local target="$1" content="$2"
  mkdir -p "$target"
  git -C "$target" init -q
  git -C "$target" config user.name "Fixture Author"
  git -C "$target" config user.email "fixture@example.invalid"
  printf '%s\n' "portable fixture" >"$target/README.md"
  printf '%s\n' "$content" >"$target/removed.txt"
  git -C "$target" add README.md removed.txt
  git -C "$target" commit -qm "seed"
  rm -f -- "$target/removed.txt"
  git -C "$target" add -u
  git -C "$target" commit -qm "remove obsolete fixture file"
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
