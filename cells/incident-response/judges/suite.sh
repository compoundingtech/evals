#!/usr/bin/env bash
# JUDGE: visible suite — node --test is GREEN on HEAD.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
( cd "$W" && node --test >/dev/null 2>&1 ) && { echo "PASS: npm test suite is GREEN on HEAD"; exit 0; } || { echo "FAIL: suite is RED on HEAD"; exit 1; }
