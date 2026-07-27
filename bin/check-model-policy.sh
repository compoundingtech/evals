#!/usr/bin/env bash
# Enforce explicit, cost-controlled model selection at every maintained working-tree launch site.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

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

  provider=""
  if [[ "$code" =~ exec[[:space:]]+claude([[:space:]]|$) ]] ||
    [[ "$code" =~ (^|[^[:alnum:]_-])claude[[:space:]]+- ]]; then
    provider="claude"
  elif [[ "$code" =~ exec[[:space:]]+codex([[:space:]]|$) ]] ||
    [[ "$code" =~ (^|[^[:alnum:]_-])codex[[:space:]]+- ]]; then
    provider="codex"
  fi
  [ -n "$provider" ] || continue

  ((launches += 1))
  if [[ "${code,,}" == *opus* ]]; then
    fail "$file:$line selects Opus; no current eval has an approved Opus exception"
  fi

  if [ "$provider" = "claude" ]; then
    ((claude_launches += 1))
    [[ "$code" == *"--model claude-sonnet-5"* ]] ||
      fail "$file:$line launches Claude without --model claude-sonnet-5"
    [[ "$code" == *"--effort medium"* ]] ||
      fail "$file:$line launches Claude without --effort medium"
  else
    ((codex_launches += 1))
    [[ "$code" == *"--model gpt-5.6-sol"* ]] ||
      fail "$file:$line launches Codex without --model gpt-5.6-sol"
    [[ "$code" == *"model_reasoning_effort=\"medium\""* ]] ||
      fail "$file:$line launches Codex without explicit medium reasoning effort"
    [[ "$code" == *"--dangerously-bypass-hook-trust"* ]] ||
      fail "$file:$line launches Codex without trusting the canonical workspace hooks"
  fi
done < <(
  rg --no-ignore -n --no-heading \
    'exec[[:space:]]+(claude|codex)|(^|[^[:alnum:]_-])(claude|codex)[[:space:]]+-' \
    cells -g '*.kdl' -g '*.sh' -g '!**/_git/**' || true
)

[ "$launches" -gt 0 ] || fail "no maintained Claude or Codex launch sites were found"

if [ "$failed" -eq 0 ]; then
  printf 'PASS: %d maintained model launches are explicit and cost-controlled (Claude %d, Codex %d)\n' \
    "$launches" "$claude_launches" "$codex_launches"
fi

exit "$failed"
