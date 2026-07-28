#!/usr/bin/env bash
set -euo pipefail

report="${RUNS_DIR:?RUNS_DIR must be set}/errors.out"
test "${RUN_errors_EXIT:?RUN_errors_EXIT must be set}" -ne 0
jq -e '
  .agents >= 4 and .errors >= 6 and
  (all(.issues[]; (.path | type == "string" and length > 0))) and
  ([.issues[] | select(.severity == "error") | .code] | index("dup-id")) != null and
  ([.issues[] | select(.severity == "error") | .code] | index("unknown-task-kind")) != null and
  ([.issues[] | select(.severity == "error") | .code] | index("render-error")) != null and
  ([.issues[] | select(.severity == "error") | .code] | index("bad-path")) != null
' "$report" >/dev/null
