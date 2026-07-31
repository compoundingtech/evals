#!/usr/bin/env bash
# Hermetic A-D integration proof for the real overnight provider termination boundary.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_head="$(git -C "$repo_root" rev-parse HEAD)"
scratch="$(mktemp -d)"
cleanup() {
  if [ "${OVN_KEEP_TMP:-0}" = "1" ]; then
    printf 'ARTIFACT_ROOT=%s\n' "$scratch"
  else
    rm -rf -- "$scratch"
  fi
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

product_cell=license-mit-codex
control_cell=ghost-bug-codex
base="$scratch/base"
git clone -q --no-hardlinks "$repo_root" "$base"
git -C "$base" branch -M main
[ "$(git -C "$base" rev-parse HEAD)" = "$source_head" ] ||
  fail "temporary main does not contain implementation head $source_head"

# The production launch gate remains intact. The hermetic fixture supplies two
# fake-provider declarations which satisfy the same reviewed budget/JSON
# command contract, then commits them so the real clean-main guard and complete
# free preflight still run.
for cell in "$product_cell" "$control_cell"; do
  sed -i 's/exec codex /exec codex --max-budget-usd 0.05 --output-format json /g' "$base/cells/$cell/$cell.kdl"
done
git -C "$base" add "cells/$product_cell/$product_cell.kdl" "cells/$control_cell/$control_cell.kdl"
GIT_AUTHOR_DATE=2026-07-31T00:00:00Z GIT_COMMITTER_DATE=2026-07-31T00:00:00Z git -C "$base" -c user.name='Overnight Receipt Fixture' -c user.email='overnight-receipt@example.invalid' commit -qm 'Install hermetic provider receipt fixture'
[ -z "$(git -C "$base" status --porcelain=v1)" ] ||
  fail "temporary main is not clean after installing the provider fixture"

fake_bin="$scratch/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
if [ "$#" -eq 2 ] && [ "$1" = login ] && [ "$2" = status ]; then
  exit 0
fi
printf 'unexpected fake codex invocation: %s\n' "$*" >&2
exit 97
EOF
chmod +x "$fake_bin/codex"

cat > "$fake_bin/st2-eval" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$#" -ge 2 ] && [ "$1" = eval ] || {
  printf 'unexpected fake st2 invocation: %s\n' "$*" >&2
  exit 97
}
cell="${2#./cells/}"
cell="${cell%/}"
: "${OVN_TEST_SCENARIO:?}"
: "${OVN_TEST_ACTION_LOG:?}"
printf '%s\n' "$cell" >> "$OVN_TEST_ACTION_LOG"

emit_usage() {
  local status="$1" cost="$2"
  printf 'USAGE_JSON={"schema_version":1,"cell":"%s","provider":"codex","model":"gpt-5.6-sol","input_tokens":10,"output_tokens":2,"cost_usd":%s,"budget_usd":0.05,"status":"%s"}\n' "$cell" "$cost" "$status"
}

if [ "$cell" != license-mit-codex ]; then
  emit_usage pass 0.01
  echo 'VERDICT: PASS'
  exit 0
fi

case "$OVN_TEST_SCENARIO" in
  a)
    emit_usage fail 0.01
    echo 'VERDICT: FAIL'
    exit 1
    ;;
  b)
    emit_usage timeout 0.01
    trap 'exit 124' TERM INT
    while :; do sleep 1; done
    ;;
  c-missing)
    echo 'VERDICT: FAIL'
    exit 1
    ;;
  c-malformed)
    echo 'USAGE_JSON={not-json'
    echo 'VERDICT: FAIL'
    exit 1
    ;;
  d)
    emit_usage fail 0.06
    echo 'VERDICT: FAIL'
    exit 1
    ;;
  *)
    printf 'unknown scenario: %s\n' "$OVN_TEST_SCENARIO" >&2
    exit 97
    ;;
esac
EOF
chmod +x "$fake_bin/st2-eval"

st2_bin="${ST2_BIN:-$(command -v st2)}"
st2_dir="${st2_bin%/*}"

assert_actions() {
  local action_log="$1" expected="$2" actual
  actual="$(paste -sd, "$action_log")"
  [ "$actual" = "$expected" ] ||
    fail "fake action sequence was $actual, expected $expected"
}

single_failure() {
  local state="$1"
  find "$state/failures" -maxdepth 1 -type f -name "$product_cell.*.env" -print -quit
}

run_case() {
  local scenario="$1" expected_actions="$2"
  local case_root="$scratch/$scenario" repo="$scratch/$scenario/repo"
  local state="$case_root/state" output="$case_root/output.log" actions="$case_root/actions.log"
  local rc failure
  mkdir -p "$case_root"
  git clone -q --no-hardlinks "$base" "$repo"
  : > "$actions"
  set +e
  (
    cd "$repo"
    PATH="$fake_bin:$st2_dir:$PATH" OVN_TEST_FAKE=1 OVN_TEST_FAKE_COMMAND="$fake_bin/st2-eval" OVN_TEST_SCENARIO="$scenario" OVN_TEST_ACTION_LOG="$actions" OVN_TEST_WATCHDOG_EXTRA=0 OVN_TEST_WATCHDOG_SECONDS=1 bash bin/overnight.sh --run --cell "$product_cell" --cell "$control_cell" --state-dir "$state"
  ) > "$output" 2>&1
  rc=$?
  set -e
  [ "$rc" -eq 1 ] || {
    tail -n 100 "$output" >&2
    fail "$scenario returned $rc, expected final status 1"
  }
  assert_actions "$actions" "$expected_actions"
  failure="$(single_failure "$state")"
  [ -n "$failure" ] || fail "$scenario did not persist the product failure record"

  case "$scenario" in
    a|b)
      [ ! -e "$state/STOPPED" ] || fail "$scenario unexpectedly wrote STOPPED"
      [ -f "$state/receipts/$control_cell.env" ] ||
        fail "$scenario did not persist the paired control PASS receipt"
      [ "$(find "$state/usage" -maxdepth 1 -type f -name '*.json' | wc -l)" -eq 2 ] ||
        fail "$scenario did not persist exactly two normalized usage receipts"
      grep -Fxq 'failure_class=product' "$failure"
      grep -Fxq 'structured_usage_receipt=1' "$failure"
      grep -Fq 'OVERNIGHT COMPLETE WITH PRODUCT FAILURES' "$output"
      if [ "$scenario" = b ]; then
        grep -Fxq 'timed_out=1' "$failure"
        jq -e '.status == "timeout" and .cost_usd == 0.01' "$state/usage/$product_cell."*.json >/dev/null
      else
        grep -Fxq 'timed_out=0' "$failure"
        jq -e '.status == "fail" and .cost_usd == 0.01' "$state/usage/$product_cell."*.json >/dev/null
      fi
      printf 'PASS %s: product %s persisted under-budget usage, paired control ran, final rc=1\n' "$scenario" "$(grep '^timed_out=' "$failure")"
      ;;
    c-missing)
      grep -Fxq 'reason=usage-receipt' "$state/STOPPED"
      grep -Fxq 'structured_usage_receipt=0' "$failure"
      [ "$(find "$state/usage" -maxdepth 1 -type f | wc -l)" -eq 0 ] ||
        fail "$scenario unexpectedly persisted a valid or invalid receipt"
      printf 'PASS %s: absent receipt stopped before control, final rc=1\n' "$scenario"
      ;;
    c-malformed)
      grep -Fxq 'reason=usage-receipt' "$state/STOPPED"
      grep -Fxq 'structured_usage_receipt=0' "$failure"
      [ "$(find "$state/usage" -maxdepth 1 -type f -name '*.invalid' | wc -l)" -eq 1 ] ||
        fail "$scenario did not preserve exactly one malformed receipt"
      printf 'PASS %s: malformed receipt stopped before control, final rc=1\n' "$scenario"
      ;;
    d)
      grep -Fxq 'reason=usage-budget' "$state/STOPPED"
      grep -Fxq 'structured_usage_receipt=1' "$failure"
      grep -Fxq 'cost_usd=0.06' "$failure"
      [ "$(find "$state/usage" -maxdepth 1 -type f -name '*.json' | wc -l)" -eq 1 ] ||
        fail "$scenario did not persist exactly one over-budget receipt"
      jq -e '.cost_usd == 0.06 and .budget_usd == 0.05' "$state/usage/$product_cell."*.json >/dev/null
      printf 'PASS %s: over-budget receipt persisted then stopped before control, final rc=1\n' "$scenario"
      ;;
  esac
}

run_case a "$product_cell,$control_cell"
run_case b "$product_cell,$control_cell"
run_case c-missing "$product_cell"
run_case c-malformed "$product_cell"
run_case d "$product_cell"

printf 'PASS: overnight A-D receipt boundary exercised real preflight, launch gate, post-termination classification, persistence, continuation, and STOPPED semantics without a provider call\n'
