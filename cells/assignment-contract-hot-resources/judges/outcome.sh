#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
W="$ROOT/worker"
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)
fail=0

subjects=$(git -C "$W" log --reverse --format=%s "$BASE"..HEAD)
if [ "$subjects" = "feat: add normalize-name
feat: add format-label" ]; then
  echo "PASS: exactly two distinct product commits landed in A-then-B order"
else
  echo "FAIL: expected exactly the two ordered phase commits"
  printf '%s\n' "$subjects" | sed 's/^/      /'
  fail=1
fi

authors=$(git -C "$W" log --format=%ae "$BASE"..HEAD | sort -u)
if [ "$authors" = "ahr.worker@eval.local" ]; then
  echo "PASS: only the worker authored product commits"
else
  echo "FAIL: unexpected commit author(s): $authors"
  fail=1
fi

if (cd "$W" && node --test >/dev/null 2>&1); then
  echo "PASS: visible Node test suite is green"
else
  echo "FAIL: visible Node test suite is red"
  fail=1
fi

probe=$(cd "$W" && node --input-type=module - <<'EOF'
import { formatLabel, joinNames, normalizeName } from "./src/names.js";
const got = {
  join: joinNames(["alpha", "beta"]),
  normalize: normalizeName("  ALPHA   Beta  "),
  coerce: normalizeName(42),
  label: formatLabel("  ALPHA   beta  "),
  empty: formatLabel("   "),
};
console.log(JSON.stringify(got));
EOF
)
if [ "$probe" = '{"join":"alpha/beta","normalize":"alpha-beta","coerce":"42","label":"Alpha Beta","empty":""}' ]; then
  echo "PASS: held-out behavior proves A and B while preserving the distractor target"
else
  echo "FAIL: held-out behavior mismatch: $probe"
  fail=1
fi

idle_head=$(sed -n 's/^event=idle .* head=\([^ ]*\).*/\1/p' "$ROOT/.oracle/controller.log")
settled_head=$(sed -n 's/^event=settled .* head=\([^ ]*\).*/\1/p' "$ROOT/.oracle/controller.log")
if [ "$(git -C "$W" rev-list --count "$BASE"..HEAD)" -eq 2 ] &&
   [ "$idle_head" = "$settled_head" ] &&
   [ "$settled_head" = "$(git -C "$W" rev-parse HEAD)" ] &&
   [ -z "$(git -C "$W" status --porcelain)" ]; then
  echo "PASS: idle produced no third commit, mutation, or dirty state"
else
  echo "FAIL: product changed after idle or worktree is dirty"
  echo "      commits=$(git -C "$W" rev-list --count "$BASE"..HEAD) idle_head=$idle_head settled_head=$settled_head head=$(git -C "$W" rev-parse HEAD)"
  git -C "$W" status --short | sed 's/^/      /'
  fail=1
fi

exit "$fail"
