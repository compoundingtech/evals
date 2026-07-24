#!/usr/bin/env bash
# JUDGE: isolation — only ir.oncall authored the pulse repo; the supervisor owns no repo.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"; SUP="$ROOT/sup"; WORKER_ID="${WORKER_ID:-ir.oncall}"
[ -d "$W/.git" ] || { echo "FAIL: no worker repo at $W — did the run happen?"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null); fail=0
bad=$(git -C "$W" log --format="%ae" 2>/dev/null | grep -vE "$WORKER_ID@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$bad" ] && echo "PASS: only $WORKER_ID (+ evals-seed base) authored commits" || { echo "FAIL: ISOLATION VIOLATION — foreign author(s): $bad"; fail=1; }
[ -d "$SUP/.git" ] && { echo "FAIL: sup dir IS a git repo (must own none)"; fail=1; } || echo "PASS: sup dir is not a git repo (structural isolation)"
echo "  changed base..HEAD: $(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')"
exit "$fail"
