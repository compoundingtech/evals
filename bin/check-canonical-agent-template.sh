#!/usr/bin/env bash
# Validate the canonical paid model-agent declaration template and publisher.
set -euo pipefail

template="${1:?canonical Agent Spec template required}"
publisher="${2:?canonical Agent Spec publisher required}"

require_once() {
  local pattern="$1" description="$2"
  if [ "$(grep -Fxc "$pattern" "$template" || true)" -ne 1 ]; then
    echo "FAIL: $template must contain exactly one $description" >&2
    exit 1
  fi
}

require_once '    AGENT_LAUNCH_HOSTED "1"' "hosted launch marker"
require_once '    AGENT_PERSONA "generalist"' "canonical persona"
require_once '    AGENT_RUNTIME_PROFILE "@PROFILE@"' "runtime-profile projection"
require_once '  argv "@ADAPTER@" "agent" "launch" "--harness" "claude" "--model" "claude-sonnet-5" "--effort" "medium" "--persona" "generalist" "--mode" "managed-unattended" "--boot" "managed-v1"' "typed managed-v1 launch"
require_once '    copy "_templates/generalist.md" ".st2/PERSONA.md"' "canonical persona overlay"
require_once '    copy "_templates/bus.st2.md" ".st2/bus.md"' "canonical bus overlay"
require_once '    git-exclude ".st2/"' "overlay exclusion"
require_once '  ding' "native DING declaration"

if grep -Fq -- '--account' "$template"; then
  echo "FAIL: $template durably pins an account" >&2
  exit 1
fi

for projection in \
  'profile="${AGENT_RUNTIME_PROFILE:-$HOME/.config/coding-agents/profile.json}"' \
  'case "$profile" in' \
  '/*) ;;' \
  '.agentSpec.adapterBin' \
  '.personas.prompts.generalist' \
  's|@PROFILE@|$profile|' \
  's|@ADAPTER@|$adapter|' \
  'cp "$persona_source" ./_templates/generalist.md'; do
  grep -Fq "$projection" "$publisher" || {
    echo "FAIL: $publisher omits canonical projection $projection" >&2
    exit 1
  }
done

echo "PASS: $template is an account-neutral managed-v1 canonical template with explicit profile and overlay projection"
