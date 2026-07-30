#!/usr/bin/env bash
set -euo pipefail

workspace="${1:-./interviewer}"
[ -d "$workspace" ] || {
  echo "interviewer workspace does not exist: $workspace" >&2
  exit 1
}
[ ! -e "$workspace/.git" ] || {
  echo "interviewer workspace is already a Git worktree: $workspace" >&2
  exit 1
}

git -C "$workspace" init -q --initial-branch=main
git -C "$workspace" add -A
GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" \
GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
  git -C "$workspace" \
    -c core.hooksPath=/dev/null \
    -c user.name=eval-fixture \
    -c user.email=eval-fixture@local \
    commit -q -m "fixture: canonical interviewer workspace"

test -z "$(git -C "$workspace" status --porcelain=v1)"
