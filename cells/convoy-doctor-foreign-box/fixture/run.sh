#!/usr/bin/env bash
# run.sh (convoy-doctor-foreign-box) — the `bin/evals run` entry point: probe then grade, in one shot.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdfb}"
"$HERE/probe.sh" "$SB"
echo
"$HERE/grade.sh" "$SB"
