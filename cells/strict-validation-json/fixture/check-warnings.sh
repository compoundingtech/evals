#!/usr/bin/env bash
set -euo pipefail

for label in warnings-default warnings-strict; do
  report="${RUNS_DIR:?RUNS_DIR must be set}/$label.out"
  jq -e '
    .errors == 0 and .warnings >= 2 and
    ([.issues[] | select(.severity == "warn") | .code] | index("dangling-supervisor")) != null and
    ([.issues[] | select(.severity == "warn") | .code] | index("dangling-import")) != null
  ' "$report" >/dev/null
done
