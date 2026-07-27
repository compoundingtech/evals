#!/usr/bin/env bash
set -euo pipefail

catalog="${CATALOG:?CATALOG must be set}/net"
for relative in workspace codex-workspace; do
  workspace="$catalog/$relative"
  (
    cd "$workspace"
    find . -type f \
      -not -path './.git/objects/*' \
      -not -path './.git/logs/*' \
      -not -path './.git/index' \
      -not -path './.git/COMMIT_EDITMSG' \
      -print0 |
      LC_ALL=C sort -z |
      xargs -0 sha256sum |
      sed "s#^#$relative #"
  )
done
