#!/usr/bin/env bash
set -euo pipefail

net="${CATALOG:?CATALOG must be set}/net"
for workspace in "$net/good-workspace" "$net/bad-workspace"; do
  git -C "$workspace" init -q -b main
  git -C "$workspace" add README.md
  git -C "$workspace" -c user.name=eval -c user.email=eval@local \
    commit -q -m "seed render target"
  test -z "$(git -C "$workspace" status --porcelain)"
done
