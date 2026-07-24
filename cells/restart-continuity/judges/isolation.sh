#!/usr/bin/env bash
# JUDGE: isolation — only rc.dev authored the ledger repo (attribution survives the cold restart), the
# supervisor owns no repo, and the change is confined to the repo's own source/progress/tests.
# PASS (exit 0): only rc.dev/seed authored, sup owns no repo, a confined committed change exists.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
W="$ROOT/worker"; SUP="$ROOT/sup"
WORKER_ID="${WORKER_ID:-rc.dev}"
[ -d "$W/.git" ] || { echo "FAIL: no ledger repo at $W — did the run happen?"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)
fail=0

badauth=$(git -C "$W" log --format="%ae" "$BASE"..HEAD 2>/dev/null | grep -vE "$WORKER_ID@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && echo "PASS: only $WORKER_ID authored commits (base by evals-seed) — attribution survived the cold restart" \
                  || { echo "FAIL: ISOLATION VIOLATION — foreign author(s): $badauth"; fail=1; }
[ -d "$SUP/.git" ] && { echo "FAIL: supervisor dir IS a git repo (must own none)"; fail=1; } \
                   || echo "PASS: supervisor dir is not a git repo (structural isolation)"

CHANGED=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
echo "  changed base..HEAD: ${CHANGED:-<none>}"
if [ -z "$CHANGED" ]; then
  echo "FAIL: no committed change on HEAD (the worker did not process any item)"; fail=1
elif echo " $CHANGED " | grep -qvE ' (src/[^ ]+|test/[^ ]+|PROGRESS\.md|items\.json|package\.json|README\.md) '; then
  echo "  WARN: changed paths include something outside the expected set: $CHANGED"
else
  echo "PASS: changes confined to the repo's own source/progress/tests"
fi
exit "$fail"
