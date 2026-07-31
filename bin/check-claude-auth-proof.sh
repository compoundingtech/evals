#!/usr/bin/env bash
# Model-free mutation gate for real-provider freshness receipts. Never invokes a
# provider: the probe is exercised only in its default dry-run path.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p .eval-runs
scratch="$(mktemp -d .eval-runs/claude-auth-check.XXXXXX)"
fake_bin="$(mktemp -d)"
marker="$fake_bin/provider-reached"
cleanup() {
  rm -rf -- "$scratch"
  rm -rf -- "$fake_bin"
}
trap cleanup EXIT

printf '%s\n' \
  '#!/usr/bin/env bash' \
  ': > "${CLAUDE_PROBE_MARKER:?}"' \
  'exit 99' >"$fake_bin/claude"
chmod +x "$fake_bin/claude"

PATH="$fake_bin:$PATH" CLAUDE_PROBE_MARKER="$marker" \
  bin/probe-claude-auth.sh --dry-run --receipt .eval-runs/proof.env \
  >"$scratch/dry-run.out"
[ ! -e "$marker" ] || {
  echo "FAIL: Claude auth probe dry-run reached the provider binary" >&2
  exit 1
}
grep -Fq 'DRY RUN ONLY' "$scratch/dry-run.out"
grep -Fq 'claude-sonnet-5, medium effort' "$scratch/dry-run.out"
grep -Fq 'USD 0.05 maximum' "$scratch/dry-run.out"

auth_context_sha256="$(
  printf '%s\0' \
    "${XDG_STATE_HOME-__UNSET__}" \
    "${XDG_CONFIG_HOME-__UNSET__}" \
    "${CLAUDE_CONFIG_DIR-__UNSET__}" |
    sha256sum | awk '{ print $1 }'
)"
now="$(date -u +%s)"
source_commit="$(git rev-parse HEAD)"
cli_version="$(claude --version | awk 'NR == 1 { print $1 }')"

write_receipt() {
  local destination="$1" completed="$2" context="$3" source="$4" response="$5"
  umask 077
  printf '%s\n' \
    "receipt_version=1" \
    "result=PASS" \
    "probe=real-provider-one-turn" \
    "model=claude-sonnet-5" \
    "effort=medium" \
    "cli_version=$cli_version" \
    "source_commit=$source" \
    "completed_epoch=$completed" \
    "auth_context_sha256=$context" \
    "response=$response" \
    "input_tokens=2" \
    "output_tokens=3" \
    "cache_creation_input_tokens=0" \
    "cache_read_input_tokens=0" \
    "total_cost_usd=0.001" \
    >"$destination"
}

valid="$scratch/valid.env"
write_receipt "$valid" "$now" "$auth_context_sha256" "$source_commit" AUTH_OK
bin/validate-claude-auth-proof.sh "$valid" >/dev/null

expect_rejected() {
  local file="$1" expected="$2"
  if bin/validate-claude-auth-proof.sh "$file" >"$scratch/rejected.out" 2>&1; then
    echo "FAIL: invalid Claude auth proof was accepted: $file" >&2
    exit 1
  fi
  grep -Fq "$expected" "$scratch/rejected.out" || {
    sed -n '1,80p' "$scratch/rejected.out" >&2
    echo "FAIL: invalid proof rejection did not explain: $expected" >&2
    exit 1
  }
}

metadata_only="$scratch/metadata-only.env"
printf 'loggedIn=true\n' >"$metadata_only"
chmod 600 "$metadata_only"
expect_rejected "$metadata_only" 'missing, duplicate, or unknown fields'

stale="$scratch/stale.env"
write_receipt "$stale" "$((now - 601))" "$auth_context_sha256" "$source_commit" AUTH_OK
expect_rejected "$stale" 'stale or future-dated'

wrong_context="$scratch/wrong-context.env"
write_receipt "$wrong_context" "$now" "$(printf wrong | sha256sum | awk '{ print $1 }')" "$source_commit" AUTH_OK
expect_rejected "$wrong_context" 'state/config context changed'

wrong_source="$scratch/wrong-source.env"
write_receipt "$wrong_source" "$now" "$auth_context_sha256" "$(printf '0%.0s' {1..40})" AUTH_OK
expect_rejected "$wrong_source" 'source commit changed'

wrong_response="$scratch/wrong-response.env"
write_receipt "$wrong_response" "$now" "$auth_context_sha256" "$source_commit" 'AUTH OK'
expect_rejected "$wrong_response" 'exact AUTH_OK'

duplicate="$scratch/duplicate.env"
cp "$valid" "$duplicate"
printf 'result=PASS\n' >>"$duplicate"
expect_rejected "$duplicate" 'missing, duplicate, or unknown fields'

public="$scratch/public.env"
write_receipt "$public" "$now" "$auth_context_sha256" "$source_commit" AUTH_OK
chmod 644 "$public"
expect_rejected "$public" 'must not be group/world accessible'

over_budget="$scratch/over-budget.env"
write_receipt "$over_budget" "$now" "$auth_context_sha256" "$source_commit" AUTH_OK
sed -i 's/^total_cost_usd=.*/total_cost_usd=0.051/' "$over_budget"
expect_rejected "$over_budget" 'exceeded the USD 0.05 bound'

if ANTHROPIC_API_KEY=synthetic-override \
  bin/validate-claude-auth-proof.sh "$valid" >"$scratch/rejected.out" 2>&1; then
  echo "FAIL: API-key override did not invalidate the OAuth proof" >&2
  exit 1
fi
grep -Fq 'ANTHROPIC_API_KEY is present' "$scratch/rejected.out"
if CLAUDE_CODE_OAUTH_TOKEN=synthetic-override \
  bin/validate-claude-auth-proof.sh "$valid" >"$scratch/rejected.out" 2>&1; then
  echo "FAIL: OAuth-token override did not invalidate the stored OAuth proof" >&2
  exit 1
fi
grep -Fq 'CLAUDE_CODE_OAUTH_TOKEN is present' "$scratch/rejected.out"

grep -Fq \
  'claude --model claude-sonnet-5 --effort medium --permission-mode dontAsk --safe-mode --tools "" --no-session-persistence --max-budget-usd 0.05 --output-format json --print "Return exactly AUTH_OK and no other text."' \
  bin/probe-claude-auth.sh || {
    echo "FAIL: real Claude auth probe is not the reviewed exact bounded command" >&2
    exit 1
  }

printf '%s\n' \
  "PASS: Claude auth probe dry-run cannot reach the provider and exposes its exact bounded shape" \
  "PASS: fresh exact one-turn receipt passes without reading secret values" \
  "PASS: metadata-only, stale, context/source-drifted, override-tainted, public, non-exact, duplicate, and over-budget receipts fail closed"
