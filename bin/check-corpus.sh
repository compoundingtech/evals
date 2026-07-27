#!/usr/bin/env bash
# Complete free preflight for the current overnight corpus. Never starts a model seat.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

expected_source="9ab1723"
expected_version_prefix="st2 0.1.0 — running from local source ($expected_source, "
actual_version="$(st2 --version)"
[[ "$actual_version" == "$expected_version_prefix"*")" ]] || {
  echo "FAIL: expected st2 0.1.0 from pinned source $expected_source, found $actual_version" >&2
  exit 1
}
echo "PASS: pinned runner source $expected_source ($actual_version)"

mapfile -d '' shell_files < <(
  find bin cells -type f -name '*.sh' -not -path '*/_git/*' -print0 | sort -z
)
bash -n "${shell_files[@]}"
echo "PASS: ${#shell_files[@]} shell files parse"

bin/check-preflight-safety.sh
bin/check-model-policy.sh
bin/check-retired-surfaces.sh
bin/model-seat-inventory.sh >/dev/null
bin/check-event-first.sh
bin/check-kdl-parse.sh
bin/check-st2-semantic.sh
bin/check-fixture-reset.sh
bin/check-harness-contract.sh
bin/check-overnight-policy.sh
bin/check-no-pii.sh
bin/generate-catalog.sh --check
git diff --check HEAD

echo "PASS: complete model-free corpus preflight"
