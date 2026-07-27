#!/usr/bin/env bash
set -euo pipefail

catalog="${CATALOG:?CATALOG must be set}/net"
for workspace in "$catalog/workspace" "$catalog/codex-workspace"; do
  git -C "$workspace" init -q -b main
  git -C "$workspace" add README.md
  git -C "$workspace" \
    -c user.name=eval \
    -c user.email=eval@local \
    commit -q -m "seed hook materialization workspace"

  test -z "$(git -C "$workspace" status --porcelain)"
  printf 'seeded clean workspace: %s\n' "$workspace"
done
