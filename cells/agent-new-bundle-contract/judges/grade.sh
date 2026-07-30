#!/usr/bin/env bash
set -euo pipefail

mode="${1:?grade mode required}"
root="${CATALOG:?CATALOG required}"

grade_bundle() {
  local name="$1" expected_identity="$2" expected_harness="$3" expected_model="$4" expected_effort="$5" expected_persona="$6"
  local out="$root/out/$name"
  local intent="$out/intent.json"
  local kdl="$out/agents/evalhost/$expected_identity/agent.kdl"
  local inbox="$out/agents/evalhost/$expected_identity/resources/inbox/0001-session-goal.md"

  jq -e --arg identity "$expected_identity" \
    '.schema == "axe.agent-creation-intent.v1" and .decision == "commit" and .identity == $identity' \
    "$intent" >/dev/null
  grep -Fqx "  identity \"$expected_identity\"" "$kdl"
  grep -Fqx '  host "evalhost"' "$kdl"
  if [ "$name" = implementation ]; then
    grep -Fqx '  workspace "/workspace/dotfiles"' "$kdl"
    grep -Fqx '  supervisor "evalhost.root"' "$kdl"
  else
    grep -Fqx '  workspace "/workspace/livestore"' "$kdl"
    ! grep -Eq '^[[:space:]]*supervisor ' "$kdl"
  fi
  grep -Fqx '    AGENT_LAUNCH_HOSTED "1"' "$kdl"
  grep -Fqx "    AGENT_PERSONA \"$expected_persona\"" "$kdl"
  grep -Fqx "    ST_AGENT \"evalhost.$expected_identity\"" "$kdl"
  grep -Fqx "  argv \"/nix/store/axe/bin/axe\" \"agent\" \"launch\" \"--harness\" \"$expected_harness\" \"--model\" \"$expected_model\" \"--effort\" \"$expected_effort\" \"--persona\" \"$expected_persona\" \"--mode\" \"managed-unattended\" \"--boot\" \"managed-v1\"" "$kdl"
  grep -Fqx "    copy \"_templates/$expected_persona.md\" \".st2/PERSONA.md\"" "$kdl"
  test -s "$inbox"
}

case "$mode" in
  implementation)
    grade_bundle implementation dotfiles.axe.issue-40.implementation codex gpt-5.6-sol high generalist
    ;;
  review)
    grade_bundle review livestore.pr-1520.review claude claude-sonnet-5 medium reviewer
    ;;
  inbox)
    impl="$root/out/implementation/agents/evalhost/dotfiles.axe.issue-40.implementation"
    grep -Fqx 'Goal: Implement Axe issue 40 end to end, including tests and live verification.' \
      "$impl/resources/inbox/0001-session-goal.md"
    grep -Fqx -- '- https://github.com/compoundingtech/axe/issues/40' \
      "$impl/resources/inbox/0001-session-goal.md"
    ! grep -Eq 'goal|references|github\.com' "$impl/agent.kdl"
    ;;
  *)
    echo "unknown grade mode: $mode" >&2
    exit 2
    ;;
esac
