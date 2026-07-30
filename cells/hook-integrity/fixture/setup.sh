#!/usr/bin/env bash
set -euo pipefail

catalog="${CATALOG:?CATALOG must be set}/net"
for workspace in "$catalog/workspace" "$catalog/codex-workspace"; do
  git -C "$workspace" init -q -b main
  git -C "$workspace" add README.md
  # Seed history is fixture data; plumbing keeps agent commit hooks out of immutable setup.
  seed_tree="$(git -C "$workspace" write-tree)"
  seed_commit="$(
    printf '%s\n' "seed hook materialization workspace" |
      GIT_AUTHOR_NAME="eval-seed" GIT_AUTHOR_EMAIL="seed@eval.local" \
      GIT_COMMITTER_NAME="eval-seed" GIT_COMMITTER_EMAIL="seed@eval.local" \
      GIT_AUTHOR_DATE="2026-07-30T00:00:00Z" GIT_COMMITTER_DATE="2026-07-30T00:00:00Z" \
      git -C "$workspace" commit-tree "$seed_tree"
  )"
  git -C "$workspace" update-ref refs/heads/main "$seed_commit"

  test -z "$(git -C "$workspace" status --porcelain)"
  printf 'seeded clean workspace: %s\n' "$workspace"
done
