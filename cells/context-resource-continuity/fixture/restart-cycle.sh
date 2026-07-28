#!/usr/bin/env bash
set -euo pipefail

net="${CATALOG:?CATALOG must be set}/net"
for cycle in 1 2; do
  st2 up --once --catalog "$net" --host cr >/dev/null
  st2 down --catalog "$net" --host cr >/dev/null
  test "$(PTY_ROOT="$net/pty" pty list --json | jq '[.[] | select(.status == "running")] | length')" -eq 0
  printf 'CYCLE-%s-GREEN-7b9d\n' "$cycle"
done
echo "CLEANUP-GREEN-7b9d"
