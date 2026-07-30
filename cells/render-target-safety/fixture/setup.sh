#!/usr/bin/env bash
set -euo pipefail

net="${CATALOG:?CATALOG must be set}/net"
author_name="$(git config --get user.name)"
author_email="$(git config --get user.email)"
[ -n "$author_name" ] && [ -n "$author_email" ] || {
  echo "FAIL: the invoking Git identity must be configured before materializing the eval" >&2
  exit 1
}
for workspace in "$net/good-workspace" "$net/bad-workspace"; do
  git -C "$workspace" init -q -b main
  git -C "$workspace" add README.md
  git -C "$workspace" -c user.name="$author_name" -c user.email="$author_email" \
    commit -q -m "seed render target"
  test -z "$(git -C "$workspace" status --porcelain)"
done
