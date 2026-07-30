#!/usr/bin/env bash
set -euo pipefail

mode="${1:?grade mode required}"
root="${CATALOG:?CATALOG required}"
result="$root/interviewer/result"
intent="$result/intent.json"
identity="dotfiles.axe.issue-40.implementation"
target="$result/agents/evalhost/$identity"
kdl="$target/agent.kdl"
inbox="$target/resources/inbox/0001-session-goal.md"

case "$mode" in
  intent)
    jq -e '
      .schema == "axe.agent-creation-intent.v1" and
      .decision == "commit" and
      .identity == "dotfiles.axe.issue-40.implementation" and
      .workspace == "/workspace/dotfiles" and
      (.goal | test("implement"; "i") and test("test"; "i") and test("live"; "i")) and
      .references == ["https://github.com/compoundingtech/axe/issues/40"] and
      .trajectory == {
        "harness": "codex",
        "model": "gpt-5.6-sol",
        "effort": "high",
        "persona": "generalist",
        "mode": "managed-unattended",
        "boot": "managed-v1"
      }
    ' "$intent" >/dev/null
    ;;
  bundle)
    grep -Fqx "  identity \"$identity\"" "$kdl"
    grep -Fqx '  host "evalhost"' "$kdl"
    grep -Fqx '  workspace "/workspace/dotfiles"' "$kdl"
    grep -Fqx '    AGENT_LAUNCH_HOSTED "1"' "$kdl"
    grep -Fqx "    ST_AGENT \"evalhost.$identity\"" "$kdl"
    grep -Fqx '  argv "/nix/store/axe/bin/axe" "agent" "launch" "--harness" "codex" "--model" "gpt-5.6-sol" "--effort" "high" "--persona" "generalist" "--mode" "managed-unattended" "--boot" "managed-v1"' "$kdl"
    grep -Fqx '    copy "_templates/generalist.md" ".st2/PERSONA.md"' "$kdl"
    ;;
  inbox)
    grep -Eiq '^Goal: .*implement.*test.*live' "$inbox"
    grep -Fqx -- '- https://github.com/compoundingtech/axe/issues/40' "$inbox"
    ;;
  boundary)
    test "$(find "$root/interviewer" -type f -name '*.kdl' | wc -l)" -eq 1
    ! jq -e 'has("account") or has("provider_argv")' "$intent" >/dev/null
    ! grep -Eq 'argv "(claude|codex|opencode|pi)"|--account|goal|references|github\.com' "$kdl"
    ;;
  *)
    echo "unknown grade mode: $mode" >&2
    exit 2
    ;;
esac
