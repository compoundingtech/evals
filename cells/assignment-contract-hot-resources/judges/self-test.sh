#!/usr/bin/env bash
set -euo pipefail

CELL="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

cp -R "$CELL/fixture/." "$SANDBOX/"
(cd "$SANDBOX" && bash ./materialize.sh)

"$SANDBOX/bin/resource-read" github-issue://eval/names-normalize >/dev/null

cat >>"$SANDBOX/worker/src/names.js" <<'EOF'

export function normalizeName(value) {
  return String(value).trim().toLowerCase().replace(/\s+/g, "-");
}
EOF
sed -i 's/{ joinNames }/{ joinNames, normalizeName }/' "$SANDBOX/worker/test/names.test.js"
cat >>"$SANDBOX/worker/test/names.test.js" <<'EOF'

test("normalizeName canonicalizes values", () => {
  assert.equal(normalizeName("  ALPHA   Beta  "), "alpha-beta");
  assert.equal(normalizeName(42), "42");
});
EOF
(cd "$SANDBOX/worker" && node --test >/dev/null)
git -C "$SANDBOX/worker" add src/names.js test/names.test.js
git -C "$SANDBOX/worker" commit -q -m "feat: add normalize-name"
a_commit="$(git -C "$SANDBOX/worker" rev-parse HEAD)"

sed -i 's|github-issue://eval/names-normalize|github-issue://eval/names-format-label|' \
  "$SANDBOX/agent-spec.kdl"
"$SANDBOX/bin/resource-read" github-issue://eval/names-format-label >/dev/null

cat >>"$SANDBOX/worker/src/names.js" <<'EOF'
export function formatLabel(value) {
  const normalized = normalizeName(value);
  if (normalized === "") return "";
  return normalized.split("-").filter(Boolean).map((part) => part[0].toUpperCase() + part.slice(1)).join(" ");
}
EOF
sed -i 's/{ joinNames, normalizeName }/{ formatLabel, joinNames, normalizeName }/' \
  "$SANDBOX/worker/test/names.test.js"
cat >>"$SANDBOX/worker/test/names.test.js" <<'EOF'

test("formatLabel presents normalized values", () => {
  assert.equal(formatLabel("  ALPHA   beta  "), "Alpha Beta");
  assert.equal(formatLabel("   "), "");
});
EOF
(cd "$SANDBOX/worker" && node --test >/dev/null)
git -C "$SANDBOX/worker" add src/names.js test/names.test.js
git -C "$SANDBOX/worker" commit -q -m "feat: add format-label"
b_commit="$(git -C "$SANDBOX/worker" rev-parse HEAD)"

sed -i '/^[[:space:]]*resource "work"/d' "$SANDBOX/agent-spec.kdl"
cat >"$SANDBOX/.oracle/controller.log" <<EOF
event=boot pid=4242 session=ahr.worker head=$(<"$SANDBOX/.oracle/base") work=github-issue://eval/names-normalize epoch=1
event=phase-a-complete pid=4242 session=ahr.worker head=$a_commit work=github-issue://eval/names-normalize epoch=2
event=rebind-b pid=4242 session=ahr.worker head=$a_commit work=github-issue://eval/names-format-label epoch=3
event=phase-b-complete pid=4242 session=ahr.worker head=$b_commit work=github-issue://eval/names-format-label epoch=4
event=remove-work pid=4242 session=ahr.worker head=$b_commit work=none epoch=5
event=idle pid=4242 session=ahr.worker head=$b_commit work=none epoch=6
event=settled pid=4242 session=ahr.worker head=$b_commit work=none epoch=7
event=ready-to-close pid=4242 session=ahr.worker head=$b_commit work=none epoch=8
EOF
sed -i 's/ pid=4242 / pid=4242 created_at=seed /' "$SANDBOX/.oracle/controller.log"

for id in ahr.sup ahr.worker ahr.controller requester; do
  mkdir -p "$SANDBOX/bus/$id/inbox" "$SANDBOX/bus/$id/archive"
done
cat >"$SANDBOX/bus/ahr.worker/archive/1000-deleg.md" <<'EOF'
---
from: ahr.sup
---
Begin the work declared in durable context.
EOF
for timestamp in 1100 1200 1300; do
  printf '%s\n' '---' 'from: ahr.sup' '---' \
    'Continue reconciling the current durable declaration.' \
    >"$SANDBOX/bus/ahr.worker/archive/$timestamp-guidance.md"
done
cat >"$SANDBOX/bus/ahr.worker/archive/2000-rebind.md" <<'EOF'
---
from: ahr.controller
---
Durable Agent Spec resources changed.
EOF
cat >"$SANDBOX/bus/ahr.worker/archive/4000-idle.md" <<'EOF'
---
from: ahr.controller
---
Durable Agent Spec resources changed.
EOF
cat >"$SANDBOX/bus/ahr.sup/archive/1500-a.md" <<EOF
---
from: ahr.worker
---
RESOURCE_DONE uri=github-issue://eval/names-normalize commit=$a_commit
EOF
cat >"$SANDBOX/bus/ahr.sup/archive/3000-b.md" <<EOF
---
from: ahr.worker
---
RESOURCE_DONE uri=github-issue://eval/names-format-label commit=$b_commit
EOF
cat >"$SANDBOX/bus/ahr.sup/archive/5000-idle.md" <<EOF
---
from: ahr.worker
---
RESOURCE_IDLE head=$b_commit tests=pass
EOF
cat >"$SANDBOX/bus/ahr.controller/archive/6000-evidence.md" <<EOF
---
from: ahr.sup
---
HOT_RESOURCE_VERIFIED A_URI=github-issue://eval/names-normalize A_COMMIT=$a_commit B_URI=github-issue://eval/names-format-label B_COMMIT=$b_commit RESOURCE_IDLE
EOF
cat >"$SANDBOX/bus/requester/inbox/7000-confirm.md" <<EOF
---
from: ahr.controller
---
HOT_RESOURCE_VERIFIED A_URI=github-issue://eval/names-normalize A_COMMIT=$a_commit B_URI=github-issue://eval/names-format-label B_COMMIT=$b_commit RESOURCE_IDLE
EOF

CATALOG="$SANDBOX" EVAL_CELL="$CELL" bash "$CELL/judges/contract.sh"
CATALOG="$SANDBOX" EVAL_CELL="$CELL" bash "$CELL/judges/lifecycle.sh"
CATALOG="$SANDBOX" EVAL_CELL="$CELL" bash "$CELL/judges/outcome.sh"
CATALOG="$SANDBOX" EVAL_CELL="$CELL" ST_ROOT="$SANDBOX/bus" \
  bash "$CELL/judges/coordination.sh"

cp "$SANDBOX/.oracle/controller.log" "$SANDBOX/.oracle/controller.log.valid"
sed -i '/^event=idle /s/pid=4242/pid=/' "$SANDBOX/.oracle/controller.log"
if CATALOG="$SANDBOX" EVAL_CELL="$CELL" bash "$CELL/judges/lifecycle.sh" >"$SANDBOX/blank-idle-pid.out"; then
  echo "FAIL: lifecycle judge accepted an unobservable idle worker" >&2
  exit 1
fi
mv "$SANDBOX/.oracle/controller.log.valid" "$SANDBOX/.oracle/controller.log"

probe() {
  (cd "$SANDBOX/worker" && node --input-type=module - <<'EOF'
import { formatLabel, joinNames, normalizeName } from "./src/names.js";
const got = [
  joinNames(["alpha", "beta"]),
  normalizeName("  ALPHA   Beta  "),
  normalizeName(42),
  formatLabel("  ALPHA   beta  "),
  formatLabel("   "),
];
console.log(JSON.stringify(got));
EOF
)
}

test "$(probe)" = '["alpha/beta","alpha-beta","42","Alpha Beta",""]'

sed -i 's|parts\.join("/")|parts.reverse().join("/")|' "$SANDBOX/worker/src/names.js"
test "$(probe)" != '["alpha/beta","alpha-beta","42","Alpha Beta",""]'
if CATALOG="$SANDBOX" EVAL_CELL="$CELL" bash "$CELL/judges/outcome.sh" >"$SANDBOX/mutant.out"; then
  echo "FAIL: outcome judge accepted the distractor mutation" >&2
  exit 1
fi
grep -Fq "held-out behavior mismatch" "$SANDBOX/mutant.out"

echo "PASS: simulated A -> B -> idle run satisfies contract, lifecycle, and outcome judges"
echo "PASS: distractor mutation is rejected by the held-out product oracle"
echo "PASS: additional task-free supervisor guidance is not mistaken for incorrect behavior"
