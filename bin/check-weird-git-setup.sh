#!/usr/bin/env bash
# Mutation-check the corrected Weird-Git contract without launching a model.
set -euo pipefail

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

export CATALOG="$scratch"
cp -a cells/weird-git-setup/fixture/. "$scratch/"
bash cells/weird-git-setup/fixture/setup-megarepo.sh >/dev/null
worktree="$scratch/wt/feature"

cp cells/weird-git-setup/mutations/solution-clamp.js "$worktree/src/clamp.js"
git -C "$worktree" add src/clamp.js
git -C "$worktree" commit -qm "Fix above-range clamp"

for judge in worktree-resolved suite-green fix-on-feature no-leak regression-test; do
  bash "cells/weird-git-setup/judges/$judge.sh" >/dev/null || {
    echo "FAIL: complete three-test solution failed $judge" >&2
    exit 1
  }
done

cp cells/weird-git-setup/mutations/missing-regression-test.js "$worktree/test/clamp.test.js"
git -C "$worktree" add test/clamp.test.js
git -C "$worktree" commit -qm "Plant missing above-range regression"

# Removing the already-red case makes the otherwise-correct suite green; only the preservation judge should
# reject this mutation.
bash cells/weird-git-setup/judges/suite-green.sh >/dev/null || {
  echo "FAIL: missing-regression mutation did not retain an otherwise-green suite" >&2
  exit 1
}
if bash cells/weird-git-setup/judges/regression-test.sh >"$scratch/missing.out" 2>&1; then
  echo "FAIL: missing-regression mutation unexpectedly passed the preservation judge" >&2
  exit 1
fi
grep -Fq 'is not RED against the seeded above-range bug' "$scratch/missing.out" || {
  echo "FAIL: missing-regression mutation failed without the intended diagnostic" >&2
  cat "$scratch/missing.out" >&2
  exit 1
}

echo "PASS: unchanged seeded regression passes the corrected contract; deleting it fails while the suite stays green"
