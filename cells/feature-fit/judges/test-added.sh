#!/usr/bin/env bash
# JUDGE: a matching test was added at the house location (test/commands/rename.test.js) — feature-fit
# requires a test in the same place + style as the others.
#
# PASS (exit 0): test/commands/rename.test.js exists.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
if [ -f "$W/test/commands/rename.test.js" ]; then
  echo "PASS: test/commands/rename.test.js added (house location)"; exit 0
else
  echo "FAIL: no test/commands/rename.test.js (feature added without a matching test)"; exit 1
fi
