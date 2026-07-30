#!/usr/bin/env bash
# Enforce one cold-start drain followed by native DING wakeups for every maintained model seat.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

inventory="$(mktemp)"
sources="$(mktemp)"
cleanup() {
  rm -f -- "$inventory" "$sources"
}
trap cleanup EXIT

bin/model-seat-inventory.sh --no-header > "$inventory"

failed=0
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failed=1
}

required=(
  "Drain the inbox once"
  "set status available"
  "stand by for DING"
  "After any DING"
  "archive each handled item"
  "report completion or blockers over the st2 bus"
)

while IFS=$'\t' read -r cell agent _harness _workspace _st_agent source_kind source_path source_line; do
  command_text="$(sed -n "${source_line}p" "$source_path")"
  if [ "$source_kind" = "canonical-template" ]; then
    grep -Fq '"--mode" "managed-unattended"' <<< "$command_text" ||
      fail "$source_path:$source_line agent $agent canonical launch omits managed-unattended mode"
    grep -Fq '"--boot" "managed-v1"' <<< "$command_text" ||
      fail "$source_path:$source_line agent $agent canonical launch omits managed-v1 event-first boot contract"
    continue
  fi
  kdl="$source_path"
  if grep -Fq 'exec axe agent launch ' <<< "$command_text"; then
    grep -Fq -- '--mode managed-unattended' <<< "$command_text" ||
      fail "$kdl:$source_line agent $agent Axe launch omits managed-unattended mode"
    grep -Fq -- '--boot managed-v1' <<< "$command_text" ||
      fail "$kdl:$source_line agent $agent Axe launch omits managed-v1 event-first boot contract"
    continue
  fi
  for phrase in "${required[@]}"; do
    grep -Fiq "$phrase" <<< "$command_text" ||
      fail "$kdl:$source_line agent $agent does not teach '$phrase'"
  done
done < "$inventory"

find cells -type f \
  \( -name 'CLAUDE.md' -o -name 'PERSONA.md' -o -name 'AGENTS.md' \
     -o -path '*/fixture/personas/*.md' \) \
  -not -path '*/_git/*' -print0 > "$sources"

prohibited='(?i)(\b(poll|polls|polled|polling)\b[^\n]*(inbox|message)|(inbox|message)[^\n]*\b(poll|polls|polled|polling)\b|\b(sleep|timer|timers)\b[^\n]*(inbox|message)|(inbox|message)[^\n]*\b(sleep|timer|timers)\b|inbox[[:space:]-]*loop|loop[^\n]*inbox|until[^\n]*(request|assignment|delegation|ask|work)[^\n]*(arrives?|lands?))'
if xargs -0 rg -n --pcre2 "$prohibited" < "$sources"; then
  fail "agent-facing sources contain inbox polling/sleep/timer guidance"
fi

if rg -n --pcre2 \
  '(?i)^[[:space:]]*command[[:space:]]+.*exec (claude|codex)[[:space:]].*(\b(poll|polling|sleep|timer)\b|until[^\n]*(arrives?|lands?))' \
  cells/*/*.kdl; then
  fail "a model launch prompt contains polling, sleep, or timer guidance"
fi

if [ "$failed" -eq 0 ]; then
  printf 'PASS: %s model seats use one cold-start drain and event-first native DING wakeups\n' \
    "$(wc -l < "$inventory" | tr -d ' ')"
fi
exit "$failed"
