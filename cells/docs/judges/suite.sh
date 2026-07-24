#!/usr/bin/env bash
# JUDGE: visible suite — `node --test` is GREEN on HEAD (the docs change didn't break the library).
#
# PASS (exit 0): the suite passes in the worker repo.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
if ( cd "$W" && node --test >/dev/null 2>&1 ); then
  echo "PASS: npm test suite is GREEN on HEAD"; exit 0
else
  echo "FAIL: suite is RED on HEAD"; exit 1
fi
