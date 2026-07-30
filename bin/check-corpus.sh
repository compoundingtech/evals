#!/usr/bin/env bash
# Complete free preflight for the current overnight corpus. Never starts a model agent.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

source bin/st2-pin.sh
bin/check-st2-pin-consistency.sh
st2_path="$(command -v st2)"
actual_version="$(st2 --version)"
[[ "$actual_version" =~ $ST2_VERSION_REGEX ]] || {
  echo "FAIL: expected st2 0.1.0 from pinned source $ST2_SOURCE_SHORT, found $actual_version" >&2
  exit 1
}
actual_binary_sha256="$(sha256sum "$st2_path" | awk '{ print $1 }')"
[ "$actual_binary_sha256" = "$ST2_BINARY_SHA256" ] || {
  echo "FAIL: expected st2 binary sha256 $ST2_BINARY_SHA256, found $actual_binary_sha256 at $st2_path" >&2
  exit 1
}
echo "PASS: pinned runner source $ST2_SOURCE_FULL ($actual_version; sha256 $actual_binary_sha256)"

mapfile -d '' shell_files < <(
  find bin cells -type f -name '*.sh' -not -path '*/_git/*' -print0 | sort -z
)
bash -n "${shell_files[@]}"
echo "PASS: ${#shell_files[@]} shell files parse"

bin/check-preflight-safety.sh
bin/check-agent-new-renderer-security.sh
bin/check-model-policy.sh
bin/check-model-policy-mutations.sh
bin/check-canonical-agent-template-mutations.sh
bin/check-run-history.sh
attempt_baseline="${EVALS_EVIDENCE_BASELINE_REF:-}"
if [ -z "$attempt_baseline" ] && git rev-parse --verify origin/main^{commit} >/dev/null 2>&1; then
  candidate_baseline="$(git merge-base HEAD origin/main)"
  current_commit="$(git rev-parse HEAD)"
  if [ "$candidate_baseline" != "$current_commit" ] &&
    git cat-file -e "$candidate_baseline:evidence/agent-new-interview-attempts.tsv" 2>/dev/null; then
    attempt_baseline="$candidate_baseline"
  fi
fi
if [ -n "$attempt_baseline" ]; then
  bin/check-agent-new-interview-attempts.sh --baseline "$attempt_baseline"
else
  bin/check-agent-new-interview-attempts.sh
fi
bin/check-agent-new-interview-attempts-mutations.sh
bin/check-retired-surfaces.sh
bin/model-agent-inventory.sh >/dev/null
bin/check-event-first.sh
bin/check-kdl-parse.sh
bin/check-st2-semantic.sh
bin/check-fixture-reset-terminal.sh
bin/check-harness-contract.sh
bin/check-vrs-scope-drift.sh
bin/check-vrs-variations.sh
bin/check-weird-git-setup.sh
bin/check-overnight-policy.sh
bin/check-no-pii.sh
bin/check-no-pii-history.sh
bin/generate-catalog.sh --check
git diff --check HEAD

echo "PASS: complete model-free corpus preflight"
