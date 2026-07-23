#!/usr/bin/env bash
# JUDGE: visible suite — node --test is GREEN after the migration.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
( cd "$W" && node --test >/dev/null 2>&1 ) && { echo "PASS: suite green (node --test)"; exit 0; } || { echo "FAIL: suite NOT green"; exit 1; }
