#!/usr/bin/env bash
# JUDGE: isolation — only dm.dev authored the widget repo; the supervisor owns no repo.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"; SUP="$ROOT/sup"; WORKER_ID="${WORKER_ID:-dm.dev}"
[ -d "$W/.git" ] || { echo "FAIL: no worker repo at $W — did the run happen?"; exit 1; }
fail=0
bad=$(git -C "$W" log --format="%ae" 2>/dev/null | grep -vE "$WORKER_ID@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$bad" ] && echo "PASS: only $WORKER_ID (+ evals-seed base) authored commits" || { echo "FAIL: ISOLATION VIOLATION — foreign author(s): $bad"; fail=1; }
[ -d "$SUP/.git" ] && { echo "FAIL: supervisor dir IS a git repo (must own none)"; fail=1; } || echo "PASS: supervisor dir is not a git repo (structural isolation)"
exit "$fail"
