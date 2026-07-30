#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
git -C "$repo_root" worktree add --detach "$tmp/repo" HEAD >/dev/null
git -C "$tmp/repo" switch -c main >/dev/null
set +e
OVN_TEST_FAKE=1 OVN_TEST_WATCHDOG_EXTRA=0 \
  bash "$tmp/repo/bin/overnight.sh" --run --cell hook-integrity --state-dir "$tmp/state" >"$tmp/out" 2>&1
rc=$?
set -e
printf 'A_CASE_RC=%s\n' "$rc"
sed -n '1,20p' "$tmp/out"
exit "$rc"
