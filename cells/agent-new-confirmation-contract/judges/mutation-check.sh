#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG required}"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

expect_rejected() {
  local name="$1" mode="$2"
  if CATALOG="$scratch/$name" bash ./judges/grade.sh "$mode" >/dev/null 2>&1; then
    echo "FAIL: planted $name mutation passed confirmation grader" >&2
    exit 1
  fi
}

mkdir -p "$scratch/no-confirm/out"
cp -a "$root/out/pending" "$scratch/no-confirm/out/confirmed"
expect_rejected no-confirm confirmed

mkdir -p "$scratch/no-tombstone/out"
cp -a "$root/out/confirmed" "$scratch/no-tombstone/out/confirmed"
sed -i 's/retired #true/retired #false/' \
  "$scratch/no-tombstone/out/confirmed/agents/dev3/global.coding-agents.session-creation.interview-eval/agent.kdl"
expect_rejected no-tombstone confirmed

mkdir -p "$scratch/cancel-published/out"
for name in rejected eof clean-detach external-sigint terminal-ctrl-c; do
  cp -a "$root/out/$name" "$scratch/cancel-published/out/$name"
done
cp -a \
  "$root/out/confirmed/agents/dev3/dotfiles.cos-misc.axe-40.implementation" \
  "$scratch/cancel-published/out/rejected/agents/dev3/"
expect_rejected cancel-published cancelled

mkdir -p "$scratch/ctrl-c-retired/out"
for name in rejected eof clean-detach external-sigint terminal-ctrl-c; do
  cp -a "$root/out/$name" "$scratch/ctrl-c-retired/out/$name"
done
sed -i 's/retired #false/retired #true/' \
  "$scratch/ctrl-c-retired/out/terminal-ctrl-c/agents/dev3/global.coding-agents.session-creation.interview-eval/agent.kdl"
expect_rejected ctrl-c-retired cancelled

echo "PASS: confirmation mutations fail held-out graders"
