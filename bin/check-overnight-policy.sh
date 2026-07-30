#!/usr/bin/env bash
# Prove dry-run ordering and make the informational-vs-hard usage stop policy visible.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

plan="$(mktemp)"
opt_in_plan="$(mktemp)"
queue_plan="$(mktemp)"
model_free_plan="$(mktemp)"
dry_prefix="$(mktemp)"
rejection_output="$(mktemp)"
fake_bin="$(mktemp -d)"
provider_marker="$fake_bin/provider-reached"
cleanup() {
  rm -f -- "$plan" "$opt_in_plan" "$queue_plan" "$model_free_plan" "$dry_prefix" "$rejection_output"
  rm -rf -- "$fake_bin"
}
trap cleanup EXIT

bin/overnight.sh --dry-run > "$plan"
bin/overnight.sh --dry-run --allow-informational-reset-banner > "$opt_in_plan"
queue=(
  license-mit
  license-mit-codex
  ghost-bug
  ghost-bug-codex
  poisoned-pr
  poisoned-pr-codex
)
queue_args=()
for cell in "${queue[@]}"; do
  queue_args+=(--cell "$cell")
done
bin/overnight.sh --dry-run "${queue_args[@]}" > "$queue_plan"
bin/overnight.sh --dry-run --cell hook-integrity > "$model_free_plan"

mapfile -t inventory_rows < <(bin/corpus-inventory.sh --no-header)
expected_first="${inventory_rows[0]%%$'\t'*}"
actual_first="$(awk 'NR == 2 { print $1 }' "$plan")"
[ "$actual_first" = "$expected_first" ] || {
  echo "FAIL: overnight dry-run starts with $actual_first, expected lexical $expected_first" >&2
  exit 1
}

expected_cells="${#inventory_rows[@]}"
grep -Fq "$expected_cells selected cells; complete lexical inventory; sequential, no overlap." "$plan"
grep -Fq 'DRY RUN ONLY: no preflight command, model, judge, or eval was started.' "$plan"
grep -Fq 'NO PAID SELECTION: add repeatable --cell NAME or explicit --all together with --run.' "$plan"
grep -Fq 'a real quota/rate-limit error is a hard stop' "$plan"
grep -Fq '"N usage limit resets available" banner lets the active cell tear down' "$plan"
grep -Fq 'then writes STOPPED before the next cell by default' "$plan"
grep -Fq 'INFORMATIONAL BANNER OPT-IN NOT SELECTED' "$plan"
grep -Fq 'that choice can spend more model quota' "$plan"
grep -Fq 'INFORMATIONAL BANNER OPT-IN SELECTED' "$opt_in_plan"
grep -Fq 'Hard quota/rate-limit errors still stop.' "$opt_in_plan"
grep -Fq 'DRY RUN ONLY: no preflight command, model, judge, or eval was started.' "$opt_in_plan"

mapfile -t planned_queue < <(sed -n "2,$((1 + ${#queue[@]}))p" "$queue_plan" | awk '{ print $1 }')
[ "${planned_queue[*]}" = "${queue[*]}" ] || {
  echo "FAIL: repeatable --cell does not preserve exact CLI order" >&2
  printf 'expected: %s\nactual:   %s\n' "${queue[*]}" "${planned_queue[*]}" >&2
  exit 1
}
grep -Fq "${#queue[@]} selected cells; explicit CLI order; sequential, no overlap." "$queue_plan"
grep -Fq 'DRY RUN ONLY: no preflight command, model, judge, or eval was started.' "$queue_plan"
grep -Eq '^hook-integrity[[:space:]]+model-free[[:space:]]+-[[:space:]]+-[[:space:]]+0[[:space:]]+none[[:space:]]+90s$' \
  "$model_free_plan"
grep -Fq '1 selected cells; explicit CLI order; sequential, no overlap.' "$model_free_plan"
grep -Fq 'PROVIDER CHECKS: none; this selected subset is entirely model-free.' "$model_free_plan"
grep -Fq 'DRY RUN ONLY: no preflight command, model, judge, or eval was started.' "$model_free_plan"
grep -Fq \
  'PROVIDER CHECKS: Claude binary, auth metadata, and a fresh real-provider receipt before execution.' \
  "$queue_plan"
grep -Fq 'PROVIDER CHECKS: Codex binary and auth status before execution.' "$queue_plan"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  ': > "${OVERNIGHT_PROVIDER_MARKER:?}"' \
  'exit 99' > "$fake_bin/st2"
chmod +x "$fake_bin/st2"

assert_rejected_before_provider() {
  local expected="$1"
  shift
  rm -f -- "$provider_marker"
  if PATH="$fake_bin:$PATH" OVERNIGHT_PROVIDER_MARKER="$provider_marker" \
    bin/overnight.sh "$@" > "$rejection_output" 2>&1; then
    echo "FAIL: unsafe overnight arguments were accepted: $*" >&2
    exit 1
  fi
  grep -Fq "$expected" "$rejection_output" || {
    echo "FAIL: overnight rejection did not explain '$expected': $*" >&2
    sed -n '1,80p' "$rejection_output" >&2
    exit 1
  }
  [ ! -e "$provider_marker" ] || {
    echo "FAIL: rejected overnight arguments reached st2/provider execution: $*" >&2
    exit 1
  }
}

assert_rejected_before_provider \
  'FAIL: --run requires at least one --cell NAME or explicit --all' --run
assert_rejected_before_provider \
  'FAIL: --all and --cell cannot be combined' --run --all --cell license-mit
assert_rejected_before_provider \
  'FAIL: duplicate --cell selection: license-mit' \
  --run --cell license-mit --cell license-mit
assert_rejected_before_provider \
  'FAIL: unknown or retired cell: clean-compose' --run --cell clean-compose
assert_rejected_before_provider \
  'FAIL: --cell requires a name' --run --cell
assert_rejected_before_provider \
  'FAIL: Claude-selected --run requires --claude-auth-receipt from the explicit real-provider probe' \
  --run --cell license-mit
assert_rejected_before_provider \
  'FAIL: --claude-auth-receipt applies only to a Claude-selected --run' \
  --run --cell hook-integrity --claude-auth-receipt .eval-runs/unused.env

dry_exit="$(rg -n -F 'if [ "$mode" = "dry-run" ]' bin/overnight.sh | cut -d: -f1)"
launch_line="$(rg -n 'setsid .*st2 eval' bin/overnight.sh | cut -d: -f1)"
[ -n "$dry_exit" ] && [ -n "$launch_line" ] && [ "$dry_exit" -lt "$launch_line" ] || {
  echo "FAIL: overnight source does not gate the eval launch behind the dry-run exit" >&2
  exit 1
}
sed -n "1,${dry_exit}p" bin/overnight.sh > "$dry_prefix"
if rg -n --pcre2 \
  '^[[:space:]]*(?!#).*((^|[;&|()][[:space:]]*)st2[[:space:]]|exec[[:space:]]+(claude|codex)[[:space:]]|(^|[;&|()][[:space:]]*)(claude|codex|curl|wget|ssh|gh|setsid)[[:space:]])' \
  "$dry_prefix"; then
  echo "FAIL: overnight dry-run prefix contains a reconcile, provider, network, or detached-process command" >&2
  exit 1
fi
grep -Fxq 'bin/corpus-inventory.sh --no-header > "$full_inventory"' "$dry_prefix" || {
  echo "FAIL: overnight dry-run prefix does not derive the inventory through the reviewed static helper" >&2
  exit 1
}
if rg -n 'claude auth status|codex login status' "$dry_prefix"; then
  echo "FAIL: provider auth checks are reachable before the dry-run exit" >&2
  exit 1
fi
grep -Fq 'if [ "$requires_claude" -eq 1 ]; then' bin/overnight.sh
grep -Fq 'if [ "$requires_codex" -eq 1 ]; then' bin/overnight.sh
first_receipt_gate="$(
  rg -n -F 'bin/validate-claude-auth-proof.sh "$claude_auth_receipt"' bin/overnight.sh |
    head -1 | cut -d: -f1
)"
preflight_line="$(rg -n -F 'bin/check-corpus.sh' bin/overnight.sh | head -1 | cut -d: -f1)"
last_receipt_gate="$(
  rg -n -F 'bin/validate-claude-auth-proof.sh "$claude_auth_receipt"' bin/overnight.sh |
    tail -1 | cut -d: -f1
)"
[ -n "$first_receipt_gate" ] && [ -n "$preflight_line" ] && [ -n "$last_receipt_gate" ] &&
  [ "$first_receipt_gate" -lt "$preflight_line" ] && [ "$last_receipt_gate" -gt "$preflight_line" ] || {
  echo "FAIL: fresh Claude receipt is not checked both before and after free preflight" >&2
  exit 1
}
grep -Fq 'claude auth status --json >/dev/null 2>&1' bin/overnight.sh
grep -Fq 'codex login status >/dev/null 2>&1' bin/overnight.sh

grep -Fq "hard_usage_pattern='usage[ -]?limit" bin/overnight.sh
grep -Fq "informational_usage_pattern='[0-9]+ usage limit resets available'" bin/overnight.sh
grep -Fq -- '--allow-informational-reset-banner)' bin/overnight.sh
grep -Fq '[ "$hard_usage_seen" -eq 1 ]; then' bin/overnight.sh
grep -Fq '[ "$informational_usage_seen" -eq 1 ] &&' bin/overnight.sh
grep -Fq '[ "$allow_informational_reset_banner" -eq 0 ]; then' bin/overnight.sh
grep -Fq 'failure_class=product' bin/overnight.sh
grep -Fq 'paired control remains eligible' bin/overnight.sh
grep -Fq 'failure_class=infrastructure' bin/overnight.sh
grep -Fq 'failure_class=auth' bin/overnight.sh
grep -Fq 'lacks enforced per-cell spend ceiling and structured usage receipt; no provider started' bin/overnight.sh
grep -Fq 'OVERNIGHT COMPLETE WITH PRODUCT FAILURES' bin/overnight.sh

printf 'PASS: dry-run exposes %s-cell inventory, exact six-cell order, and explicit model-free selection; invalid selectors cannot reach providers; conservative usage stops remain enforced\n' \
  "$expected_cells"
