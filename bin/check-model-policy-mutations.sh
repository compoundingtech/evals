#!/usr/bin/env bash
# Prove nested provider launches cannot borrow the outer launch's approved model and effort flags.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="${1:-$repo_root/bin/check-model-policy.sh}"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

provider="clau"'de'

write_case() {
  local target="$1" nested_flags="$2"
  mkdir -p "$target"
  printf \
    'eval { command #"exec %s --model claude-sonnet-5 --effort medium --permission-mode auto --print "Launch with: st2 pty run -- exec %s %s --print Yo""# }\n' \
    "$provider" "$provider" "$nested_flags" >"$target/nested.kdl"
}

write_case "$scratch/valid" "--model claude-sonnet-5 --effort medium"
write_case "$scratch/unpinned" "--permission-mode auto"
write_case "$scratch/opus" "--model claude-opus-5 --effort medium"

valid_output="$scratch/valid.out"
bash "$checker" "$scratch/valid" >"$valid_output" 2>&1 || {
  echo "FAIL: model policy rejected two independently pinned nested launches" >&2
  cat "$valid_output" >&2
  exit 1
}
grep -Fq '2 maintained model launches' "$valid_output" || {
  echo "FAIL: valid nested control did not count both provider launches" >&2
  cat "$valid_output" >&2
  exit 1
}

unpinned_output="$scratch/unpinned.out"
if bash "$checker" "$scratch/unpinned" >"$unpinned_output" 2>&1; then
  echo "FAIL: model policy accepted an unpinned provider launch nested after a pinned outer launch" >&2
  exit 1
fi
grep -Fq 'launches Claude without --model claude-sonnet-5' "$unpinned_output" || {
  echo "FAIL: unpinned nested mutation failed without the expected model-policy diagnostic" >&2
  cat "$unpinned_output" >&2
  exit 1
}

opus_output="$scratch/opus.out"
if bash "$checker" "$scratch/opus" >"$opus_output" 2>&1; then
  echo "FAIL: model policy accepted a nested Opus launch after a pinned outer launch" >&2
  exit 1
fi
grep -Fq 'selects Opus' "$opus_output" || {
  echo "FAIL: nested Opus mutation failed without the expected policy diagnostic" >&2
  cat "$opus_output" >&2
  exit 1
}

echo "PASS: nested provider launches are counted independently; unpinned and Opus mutations fail"

mkdir -p "$scratch/axe-valid" "$scratch/axe-pinned"
printf '%s\n' \
  'team "x" { agent "i" { workspace "./i"; env { ST_AGENT "x.i" }; command #"exec axe agent launch --harness claude --persona generalist --model claude-sonnet-5 --effort medium --mode managed-unattended --boot managed-v1"#; ding } }' \
  >"$scratch/axe-valid/axe.kdl"
printf '%s\n' \
  'team "x" { agent "i" { workspace "./i"; env { ST_AGENT "x.i" }; command #"exec axe agent launch --harness claude --persona generalist --model claude-sonnet-5 --effort medium --mode managed-unattended --boot managed-v1 --account claude/example"#; ding } }' \
  >"$scratch/axe-pinned/axe.kdl"

bash "$checker" "$scratch/axe-valid" >/dev/null || {
  echo "FAIL: model policy rejected a fully typed, account-neutral Axe launch" >&2
  exit 1
}
axe_pinned_output="$scratch/axe-pinned.out"
if bash "$checker" "$scratch/axe-pinned" >"$axe_pinned_output" 2>&1; then
  echo "FAIL: model policy accepted a durable Axe account pin" >&2
  exit 1
fi
grep -Fq 'durably pins an account' "$axe_pinned_output" || {
  echo "FAIL: pinned Axe account mutation lacked the expected diagnostic" >&2
  cat "$axe_pinned_output" >&2
  exit 1
}

echo "PASS: typed Axe launches are counted and durable account pins fail"
