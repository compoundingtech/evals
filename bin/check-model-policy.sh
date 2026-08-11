#!/usr/bin/env bash
# Enforce explicit, cost-controlled model selection at every maintained working-tree launch site.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
scan_root="${1:-cells}"
[ -d "$scan_root" ] || {
  echo "FAIL: model-policy scan root is not a directory: $scan_root" >&2
  exit 1
}

failed=0
launches=0
claude_launches=0
codex_launches=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failed=1
}

while IFS=: read -r file line text; do
  trimmed="${text#"${text%%[![:space:]]*}"}"
  if [[ "$trimmed" == \#* || "$trimmed" == //* ]]; then
    continue
  fi
  code="$text"
  if [[ "$file" == *.kdl ]]; then
    code="${code%%//*}"
  fi

  code="${code//\\\"/__EVAL_ESCAPED_QUOTE__}"
  code="${code//\"/}"
  code="${code//__EVAL_ESCAPED_QUOTE__/\"}"
  remaining="$code"
  provider_regex='(^|[^[:alnum:]_-])((exec|argv)[[:space:]]+)?(claude|codex)[[:space:]]+-'
  while [[ "$remaining" =~ $provider_regex ]]; do
    match="${BASH_REMATCH[0]}"
    provider="${BASH_REMATCH[4]}"
    after="${remaining#*"$match"}"
    invocation="$match$after"
    if [[ "$after" =~ $provider_regex ]]; then
      next_match="${BASH_REMATCH[0]}"
      invocation="$match${after%%"$next_match"*}"
    fi

    ((launches += 1))
    if [[ "${invocation,,}" == *opus* ]]; then
      fail "$file:$line selects Opus; no current eval has an approved Opus exception"
    fi

    if [ "$provider" = "claude" ]; then
      ((claude_launches += 1))
      [[ "$invocation" == *"--model claude-sonnet-5"* ]] ||
        fail "$file:$line launches Claude without --model claude-sonnet-5"
      [[ "$invocation" == *"--effort medium"* ]] ||
        fail "$file:$line launches Claude without --effort medium"
    else
      ((codex_launches += 1))
      [[ "$invocation" == *"--model gpt-5.6-sol"* ]] ||
        fail "$file:$line launches Codex without --model gpt-5.6-sol"
      [[ "$invocation" == *"model_reasoning_effort=medium"* || "$invocation" == *"model_reasoning_effort=\"medium\""* ]] ||
        fail "$file:$line launches Codex without explicit medium reasoning effort"
      [[ "$invocation" == *"--dangerously-bypass-hook-trust"* ]] ||
        fail "$file:$line launches Codex without trusting the canonical workspace hooks"
    fi

    remaining="$after"
  done
done < <(
  rg --no-ignore -n --no-heading \
    '(exec[[:space:]]+|argv[[:space:]]+")?(claude|codex)"?[[:space:]]+"?-' \
    "$scan_root" -g '*.kdl' -g '*.sh' -g '!**/_git/**' || true
)

[ "$launches" -gt 0 ] || fail "no maintained Claude or Codex launch sites were found"

if [ "$failed" -eq 0 ]; then
  printf 'PASS: %d maintained model launches are explicit and cost-controlled (Claude %d, Codex %d)\n' \
    "$launches" "$claude_launches" "$codex_launches"
fi

exit "$failed"
