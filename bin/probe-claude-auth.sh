#!/usr/bin/env bash
# Explicit, bounded real-provider freshness probe. Dry-run is the default and
# can never invoke Claude; --run is a separately reviewed paid action.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="dry-run"
receipt=""

usage() {
  cat <<'EOF'
usage: bin/probe-claude-auth.sh [--dry-run|--run] --receipt .eval-runs/PATH.env

--dry-run       Print the exact bounded probe shape; start no provider (default).
--run           Execute one Claude Sonnet 5 medium turn and write a short-lived
                sanitized PASS receipt only when the real response is exact.
--receipt PATH  Receipt path below this repository's ignored .eval-runs/.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --run)
      mode="run"
      shift
      ;;
    --receipt)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      receipt="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -n "$receipt" ] || {
  echo "FAIL: --receipt is required" >&2
  exit 2
}

if [ "$mode" = "dry-run" ]; then
  printf '%s\n' \
    "DRY RUN ONLY: no auth status, provider, hook, tool, or receipt action was started." \
    "REAL PROBE: claude-sonnet-5, medium effort, tools disabled, safe mode, no session persistence." \
    "BOUND: one exact AUTH_OK response, USD 0.05 maximum, sanitized receipt at $receipt." \
    "Run only after an explicit human OAuth refresh and owner approval: add --run."
  exit 0
fi

receipt_path="$(realpath -m "$receipt")"
case "$receipt_path" in
  "$repo_root"/.eval-runs/*) ;;
  *)
    echo "FAIL: auth proof receipt must be below $repo_root/.eval-runs" >&2
    exit 2
    ;;
esac

[ "$(git branch --show-current)" = "main" ] || {
  echo "FAIL: real auth proof requires main" >&2
  exit 1
}
[ -z "$(git status --porcelain=v1)" ] || {
  echo "FAIL: real auth proof requires a clean worktree" >&2
  exit 1
}
[ -z "${ANTHROPIC_API_KEY:-}" ] || {
  echo "FAIL: ANTHROPIC_API_KEY must be unset so this proves the refreshed OAuth path" >&2
  exit 1
}
[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || {
  echo "FAIL: CLAUDE_CODE_OAUTH_TOKEN must be unset so this proves stored OAuth freshness" >&2
  exit 1
}

command -v claude >/dev/null || {
  echo "FAIL: claude is not on PATH" >&2
  exit 1
}
cli_version="$(claude --version | awk 'NR == 1 { print $1 }')"
[ "$cli_version" = "2.1.220" ] || {
  echo "FAIL: real auth proof requires Claude Code 2.1.220, found $cli_version" >&2
  exit 1
}
auth_status="$(claude auth status --json 2>/dev/null)" || {
  echo "FAIL: Claude auth metadata check failed; no real probe started" >&2
  exit 1
}
jq -e '
  .loggedIn == true and
  .authMethod == "claude.ai" and
  .apiProvider == "firstParty"
' >/dev/null <<<"$auth_status" || {
  echo "FAIL: Claude auth metadata is not a logged-in first-party subscription; no real probe started" >&2
  exit 1
}

raw="$(mktemp)"
error_log="$(mktemp)"
cleanup() {
  rm -f -- "$raw" "$error_log"
}
trap cleanup EXIT

if ! claude --model claude-sonnet-5 --effort medium --permission-mode dontAsk --safe-mode --tools "" --no-session-persistence --max-budget-usd 0.05 --output-format json --print "Return exactly AUTH_OK and no other text." >"$raw" 2>"$error_log"; then
  echo "FAIL: real Claude freshness probe was rejected; no PASS receipt written" >&2
  exit 1
fi

jq -e '.is_error == false and .result == "AUTH_OK"' "$raw" >/dev/null || {
  echo "FAIL: real Claude probe did not return exact AUTH_OK; no PASS receipt written" >&2
  exit 1
}
jq -e '
  (.usage.input_tokens | numbers) >= 0 and
  (.usage.output_tokens | numbers) >= 0 and
  (.total_cost_usd | numbers) >= 0 and
  .total_cost_usd <= 0.05
' "$raw" >/dev/null || {
  echo "FAIL: real Claude probe omitted bounded structured usage; no PASS receipt written" >&2
  exit 1
}

auth_context_sha256="$(
  printf '%s\0' \
    "${XDG_STATE_HOME-__UNSET__}" \
    "${XDG_CONFIG_HOME-__UNSET__}" \
    "${CLAUDE_CONFIG_DIR-__UNSET__}" |
    sha256sum | awk '{ print $1 }'
)"
source_commit="$(git rev-parse HEAD)"
completed_epoch="$(date -u +%s)"
input_tokens="$(jq -r '.usage.input_tokens | tostring' "$raw")"
output_tokens="$(jq -r '.usage.output_tokens | tostring' "$raw")"
cache_creation_input_tokens="$(
  jq -r '(.usage.cache_creation_input_tokens // 0) | tostring' "$raw"
)"
cache_read_input_tokens="$(
  jq -r '(.usage.cache_read_input_tokens // 0) | tostring' "$raw"
)"
total_cost_usd="$(jq -r '.total_cost_usd | tostring' "$raw")"

mkdir -p "$(dirname "$receipt_path")"
temporary="${receipt_path}.tmp.$$"
umask 077
printf '%s\n' \
  "receipt_version=1" \
  "result=PASS" \
  "probe=real-provider-one-turn" \
  "model=claude-sonnet-5" \
  "effort=medium" \
  "cli_version=$cli_version" \
  "source_commit=$source_commit" \
  "completed_epoch=$completed_epoch" \
  "auth_context_sha256=$auth_context_sha256" \
  "response=AUTH_OK" \
  "input_tokens=$input_tokens" \
  "output_tokens=$output_tokens" \
  "cache_creation_input_tokens=$cache_creation_input_tokens" \
  "cache_read_input_tokens=$cache_read_input_tokens" \
  "total_cost_usd=$total_cost_usd" \
  >"$temporary"
mv -- "$temporary" "$receipt_path"

printf '%s\n' \
  "PASS: real Claude OAuth bearer returned exact AUTH_OK" \
  "RECEIPT: $receipt" \
  "USAGE: input=$input_tokens output=$output_tokens cache_create=$cache_creation_input_tokens cache_read=$cache_read_input_tokens cost_usd=$total_cost_usd"
