#!/usr/bin/env bash
# JUDGE: isolation — only taskflow-dev authored the taskflow repo; the CoS owns no repo; changes confined.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/taskflow"; COS="$ROOT/cos"; DEV_ID="${DEV_ID:-taskflow-dev}"
[ -d "$W/.git" ] || { echo "FAIL: no taskflow repo at $W — did the run happen?"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null); fail=0
badauth=$(git -C "$W" log --format="%ae" "$BASE"..HEAD 2>/dev/null | grep -vE "$DEV_ID@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && echo "PASS: only taskflow-dev authored commits (base by evals-seed)" || { echo "FAIL: ISOLATION VIOLATION — foreign author(s): $badauth"; fail=1; }
[ -d "$COS/.git" ] && { echo "FAIL: CoS dir IS a git repo (must own none)"; fail=1; } || echo "PASS: CoS dir is not a git repo (structural isolation)"
CHANGED=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
echo "  changed base..HEAD: ${CHANGED:-<none>}"
if [ -z "$CHANGED" ]; then echo "FAIL: no committed change (the specialist did no work)"; fail=1
elif echo " $CHANGED " | grep -qvE ' (src/[^ ]+|test/[^ ]+|package\.json) '; then echo "  WARN: changed paths beyond src/test/package: $CHANGED"
else echo "PASS: changes confined to src/test"; fi
exit "$fail"
