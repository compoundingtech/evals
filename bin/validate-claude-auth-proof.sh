#!/usr/bin/env bash
# Model-free validation for a recent, sanitized real-provider proof receipt.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

receipt="${1:?usage: bin/validate-claude-auth-proof.sh RECEIPT}"
receipt_path="$(realpath -m "$receipt")"
case "$receipt_path" in
  "$repo_root"/.eval-runs/*) ;;
  *)
    echo "FAIL: Claude auth proof receipt must be below $repo_root/.eval-runs" >&2
    exit 1
    ;;
esac
[ -f "$receipt_path" ] && [ ! -L "$receipt_path" ] || {
  echo "FAIL: missing regular Claude auth proof receipt: $receipt" >&2
  exit 1
}

permissions="$(stat -c '%a' "$receipt_path")"
(( (8#$permissions & 8#077) == 0 )) || {
  echo "FAIL: Claude auth proof receipt must not be group/world accessible" >&2
  exit 1
}

expected_keys=(
  auth_context_sha256
  cache_creation_input_tokens
  cache_read_input_tokens
  cli_version
  completed_epoch
  effort
  input_tokens
  model
  output_tokens
  probe
  receipt_version
  response
  result
  source_commit
  total_cost_usd
)
mapfile -t actual_keys < <(cut -d= -f1 "$receipt_path" | LC_ALL=C sort)
[ "${actual_keys[*]}" = "${expected_keys[*]}" ] || {
  echo "FAIL: Claude auth proof receipt has missing, duplicate, or unknown fields" >&2
  exit 1
}

value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$receipt_path"
}

[ "$(value receipt_version)" = "1" ] ||
  { echo "FAIL: unsupported Claude auth proof receipt version" >&2; exit 1; }
[ "$(value result)" = "PASS" ] ||
  { echo "FAIL: Claude auth proof receipt is not PASS" >&2; exit 1; }
[ "$(value probe)" = "real-provider-one-turn" ] ||
  { echo "FAIL: receipt is not a real one-turn Claude proof" >&2; exit 1; }
[ "$(value model)" = "claude-sonnet-5" ] ||
  { echo "FAIL: Claude auth proof used the wrong model" >&2; exit 1; }
[ "$(value effort)" = "medium" ] ||
  { echo "FAIL: Claude auth proof used the wrong effort" >&2; exit 1; }
[ "$(value response)" = "AUTH_OK" ] ||
  { echo "FAIL: Claude auth proof did not record exact AUTH_OK" >&2; exit 1; }

[ -z "${ANTHROPIC_API_KEY:-}" ] || {
  echo "FAIL: ANTHROPIC_API_KEY is present; receipt proves a different auth path" >&2
  exit 1
}
[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || {
  echo "FAIL: CLAUDE_CODE_OAUTH_TOKEN is present; receipt proves a different auth path" >&2
  exit 1
}

command -v claude >/dev/null || {
  echo "FAIL: claude is not on PATH" >&2
  exit 1
}
cli_version="$(claude --version | awk 'NR == 1 { print $1 }')"
[ "$(value cli_version)" = "$cli_version" ] || {
  echo "FAIL: Claude CLI version changed since the real auth proof" >&2
  exit 1
}
[ "$cli_version" = "2.1.220" ] || {
  echo "FAIL: Claude auth proof gate requires Claude Code 2.1.220" >&2
  exit 1
}
[ "$(value source_commit)" = "$(git rev-parse HEAD)" ] || {
  echo "FAIL: source commit changed since the real auth proof" >&2
  exit 1
}

auth_context_sha256="$(
  printf '%s\0' \
    "${XDG_STATE_HOME-__UNSET__}" \
    "${XDG_CONFIG_HOME-__UNSET__}" \
    "${CLAUDE_CONFIG_DIR-__UNSET__}" |
    sha256sum | awk '{ print $1 }'
)"
[ "$(value auth_context_sha256)" = "$auth_context_sha256" ] || {
  echo "FAIL: Claude state/config context changed since the real auth proof" >&2
  exit 1
}

completed_epoch="$(value completed_epoch)"
[[ "$completed_epoch" =~ ^[0-9]+$ ]] || {
  echo "FAIL: Claude auth proof timestamp is invalid" >&2
  exit 1
}
now="$(date -u +%s)"
age=$((now - completed_epoch))
[ "$age" -ge 0 ] && [ "$age" -le 600 ] || {
  echo "FAIL: Claude auth proof is stale or future-dated (age ${age}s; maximum 600s)" >&2
  exit 1
}

for key in input_tokens output_tokens cache_creation_input_tokens cache_read_input_tokens; do
  [[ "$(value "$key")" =~ ^[0-9]+$ ]] || {
    echo "FAIL: Claude auth proof has invalid $key" >&2
    exit 1
  }
done
[[ "$(value total_cost_usd)" =~ ^[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$ ]] || {
  echo "FAIL: Claude auth proof has invalid total_cost_usd" >&2
  exit 1
}
awk -v cost="$(value total_cost_usd)" 'BEGIN { exit !(cost <= 0.05) }' || {
  echo "FAIL: Claude auth proof exceeded the USD 0.05 bound" >&2
  exit 1
}

printf 'PASS: fresh Claude provider auth receipt accepted (age=%ss, cost_usd=%s)\n' \
  "$age" "$(value total_cost_usd)"
