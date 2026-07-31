#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG required}"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
temp_rel="catalog/agents/dev3/global.coding-agents.session-creation.interview-eval/agent.kdl"
final_rel="catalog/agents/dev3/dotfiles.cos-misc.axe-40.implementation"

expect_rejected() {
  local name="$1" scenario="$2"
  if bash ./inspect-case.sh "$scenario" "$scratch/$name" >/dev/null 2>&1; then
    echo "FAIL: planted $name lifecycle mutation passed" >&2
    exit 1
  fi
}

cp -a "$root/out/success" "$scratch/no-tombstone"
sed -i 's/retired #true/retired #false/' "$scratch/no-tombstone/$temp_rel"
expect_rejected no-tombstone success

cp -a "$root/out/success" "$scratch/ding-proxy"
sed -i '/main-pty-absent/d; s/ding-state\tindeterminate/ding-state\tabsent/' \
  "$scratch/ding-proxy/trace.tsv"
expect_rejected ding-proxy success

cp -a "$root/out/success" "$scratch/duplicate-final"
mkdir -p "$scratch/duplicate-final/$final_rel/duplicate"
cp "$scratch/duplicate-final/$final_rel/agent.kdl" \
  "$scratch/duplicate-final/$final_rel/duplicate/agent.kdl"
expect_rejected duplicate-final success

cp -a "$root/out/success" "$scratch/wrong-attach"
sed -i 's/attached\tdev3\\.dotfiles\\.cos-misc\\.axe-40\\.implementation/attached\tdev3.wrong/' \
  "$scratch/wrong-attach/trace.tsv"
expect_rejected wrong-attach success

cp -a "$root/out/terminal-ctrl-c" "$scratch/ctrl-c-cancellation"
sed -i 's/retired #false/retired #true/' \
  "$scratch/ctrl-c-cancellation/$temp_rel"
expect_rejected ctrl-c-cancellation terminal-ctrl-c

echo "PASS: lifecycle mutations fail held-out inspectors"
