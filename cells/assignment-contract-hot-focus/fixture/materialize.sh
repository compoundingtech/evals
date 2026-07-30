#!/usr/bin/env bash
set -euo pipefail

mkdir -p worker/src worker/test .oracle

cat >worker/package.json <<'EOF'
{
  "name": "hot-resource-names",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF

cat >worker/src/names.js <<'EOF'
export function joinNames(parts) {
  return parts.join("/");
}
EOF

cat >worker/test/names.test.js <<'EOF'
import assert from "node:assert/strict";
import test from "node:test";

import { joinNames } from "../src/names.js";

test("joinNames preserves order with slash separators", () => {
  assert.equal(joinNames(["alpha", "beta"]), "alpha/beta");
});
EOF

git -C worker init -q -b main
git -C worker config core.hooksPath /dev/null
git_dir="$(git -C worker rev-parse --absolute-git-dir)"
printf '/AGENTS.md\n/.codex/\n/tmp/\n' >>"$git_dir/info/exclude"
git -C worker config user.name "evals seed"
git -C worker config user.email "seed@eval.local"
git -C worker add package.json src/names.js test/names.test.js
git -C worker commit -q -m "chore: seed names fixture"
git -C worker config user.name "ahr worker"
git -C worker config user.email "ahr.worker@eval.local"
git -C worker rev-parse HEAD >.oracle/base
