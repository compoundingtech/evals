#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG required}"
source_root="$root/out/implementation"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

expect_rejected() {
  local name="$1"
  if CATALOG="$scratch/$name" bash ./judges/grade.sh implementation >/dev/null 2>&1; then
    echo "FAIL: planted $name mutation passed the held-out bundle grader" >&2
    exit 1
  fi
}

cp -a "$source_root" "$scratch/raw-provider"
sed -i \
  's#argv "/nix/store/axe/bin/axe" "agent" "launch".*#argv "codex" "--model" "gpt-5.6-sol"#' \
  "$scratch/raw-provider/agents/evalhost/dotfiles.axe.issue-40.implementation/agent.kdl"
expect_rejected raw-provider

cp -a "$source_root" "$scratch/trajectory-drift"
sed -i 's/"--effort" "high"/"--effort" "medium"/' \
  "$scratch/trajectory-drift/agents/evalhost/dotfiles.axe.issue-40.implementation/agent.kdl"
expect_rejected trajectory-drift

cp -a "$source_root" "$scratch/missing-context"
rm -- "$scratch/missing-context/agents/evalhost/dotfiles.axe.issue-40.implementation/resources/inbox/0001-session-goal.md"
expect_rejected missing-context

echo "PASS: three planted bundle mutations fail the held-out grader"
