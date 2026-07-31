#!/usr/bin/env bash
set -euo pipefail

workspace="./interviewer"
mkdir -p "$workspace"
printf '%s\n' "canonical materialization fixture" > "$workspace/README.md"

git -C "$workspace" init -q --initial-branch=main
git -C "$workspace" add README.md
GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" \
GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
  git -C "$workspace" \
    -c core.hooksPath=/dev/null \
    -c user.name=eval-fixture \
    -c user.email=eval-fixture@local \
    commit -q -m "fixture: canonical materialization workspace"

test -z "$(git -C "$workspace" status --porcelain=v1)"
