#!/usr/bin/env bash
set -euo pipefail

CELL="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

cp -R "$CELL/fixture/." "$SANDBOX/"
mv "$SANDBOX/worker/_git" "$SANDBOX/worker/.git"
git -C "$SANDBOX/worker" config user.name "schickling-assistant"
git -C "$SANDBOX/worker" config user.email "261620128+schickling-assistant@users.noreply.github.com"

"$SANDBOX/bin/resource-read" github-issue://eval/widget-license-mit >/dev/null
{
  printf '%s\n\n' "MIT License" "Copyright (c) 2026 Example Corp"
  sed -n '1,$p' "$CELL/judges/mit-body.txt"
} >"$SANDBOX/worker/LICENSE"
sed -i 's/"LicenseRef-Proprietary"/"MIT"/' "$SANDBOX/worker/package.json"
git -C "$SANDBOX/worker" add LICENSE package.json
git -C "$SANDBOX/worker" commit -q -m "docs: publish under MIT"

head="$(git -C "$SANDBOX/worker" rev-parse HEAD)"
short_head="$(git -C "$SANDBOX/worker" rev-parse --short HEAD)"
for id in arc.sup arc.worker requester; do
  mkdir -p "$SANDBOX/bus/$id/inbox" "$SANDBOX/bus/$id/archive"
done
printf '%s\n' '---' 'from: arc.sup' '---' \
  'Begin the work declared in durable context.' \
  >"$SANDBOX/bus/arc.worker/archive/1000-delegation.md"
printf '%s\n' '---' 'from: arc.worker' '---' \
  "Completed github-issue://eval/widget-license-mit at $short_head; changed LICENSE and package.json; tests pass." \
  >"$SANDBOX/bus/arc.sup/archive/2000-report.md"
printf '%s\n' '---' 'from: arc.sup' '---' \
  "Verified github-issue://eval/widget-license-mit at $short_head; LICENSE and package.json complete; tests pass." \
  >"$SANDBOX/bus/requester/archive/3000-confirm.md"

CATALOG="$SANDBOX" EVAL_CELL="$CELL" bash "$CELL/judges/contract.sh"
CATALOG="$SANDBOX" EVAL_CELL="$CELL" bash "$CELL/judges/outcome.sh"
CATALOG="$SANDBOX" EVAL_CELL="$CELL" ST_ROOT="$SANDBOX/bus" \
  bash "$CELL/judges/coordination.sh"

sed -i "s/$short_head/deadbee/g" \
  "$SANDBOX/bus/arc.sup/archive/2000-report.md" \
  "$SANDBOX/bus/requester/archive/3000-confirm.md"
if CATALOG="$SANDBOX" EVAL_CELL="$CELL" ST_ROOT="$SANDBOX/bus" \
  bash "$CELL/judges/coordination.sh" >"$SANDBOX/wrong-commit.out"; then
  echo "FAIL: coordination judge accepted an unrelated abbreviated commit" >&2
  exit 1
fi
grep -Eq 'no evidenced worker|lacks the URI, actual commit' "$SANDBOX/wrong-commit.out"

echo "PASS: simulated cold start satisfies contract, outcome, and coordination judges"
echo "PASS: the actual abbreviated commit is accepted and an unrelated commit is rejected"
