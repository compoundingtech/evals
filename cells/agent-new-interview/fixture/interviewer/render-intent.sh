#!/usr/bin/env bash
set -euo pipefail

input="${1:?intent path required}"
out="${2:?output root required}"

jq -e '
  type == "object" and
  (keys | sort) == ([
    "decision", "goal", "identity", "references", "schema", "trajectory", "workspace"
  ] | sort) and
  .schema == "axe.agent-creation-intent.v1" and
  .decision == "commit" and
  (.identity | test("^[a-z0-9][a-z0-9.-]*[a-z0-9]$")) and
  (.workspace | test("^/[-A-Za-z0-9._/+:]+$")) and
  (.goal | type == "string" and length > 0 and test("[\"\\n\\r]") | not) and
  (.references | type == "array" and length > 0 and
    all(.[]; type == "string" and test("^https://github\\.com/"))) and
  (.trajectory | type == "object") and
  (.trajectory | keys | sort) == ([
    "boot", "effort", "harness", "mode", "model", "persona"
  ] | sort) and
  .trajectory.mode == "managed-unattended" and
  .trajectory.boot == "managed-v1" and
  .trajectory.persona == "generalist" and
  .trajectory.harness == "codex" and
  .trajectory.model == "gpt-5.6-sol" and
  .trajectory.effort == "high"
' "$input" >/dev/null

identity="$(jq -r .identity "$input")"
workspace="$(jq -r .workspace "$input")"
goal="$(jq -r .goal "$input")"
target="$out/agents/evalhost/$identity"

mkdir -p "$target/resources/inbox"
cp "$input" "$out/intent.json"

{
  printf 'agent "%s" {\n' "$identity"
  printf '  identity "%s"\n' "$identity"
  printf '  host "evalhost"\n'
  printf '  workspace "%s"\n\n' "$workspace"
  printf '  restart {\n'
  printf '    attempts 3\n'
  printf '    interval "60s"\n'
  printf '    delay "0s"\n'
  printf '    mode "delay"\n'
  printf '  }\n\n'
  printf '  env {\n'
  printf '    AGENT_LAUNCH_HOSTED "1"\n'
  printf '    AGENT_PERSONA "generalist"\n'
  printf '    AGENT_RUNTIME_PROFILE "/etc/coding-agents/profile.json"\n'
  printf '    ST_AGENT "evalhost.%s"\n' "$identity"
  printf '  }\n\n'
  printf '  argv "/nix/store/axe/bin/axe" "agent" "launch" "--harness" "codex" "--model" "gpt-5.6-sol" "--effort" "high" "--persona" "generalist" "--mode" "managed-unattended" "--boot" "managed-v1"\n'
  printf '  ding\n\n'
  printf '  render {\n'
  printf '    copy "_templates/generalist.md" ".st2/PERSONA.md"\n'
  printf '    copy "_templates/bus.st2.md" ".st2/bus.md"\n'
  printf '    git-exclude ".st2/"\n'
  printf '  }\n'
  printf '}\n'
} >"$target/agent.kdl"

{
  printf '%s\n' '---'
  printf 'subject: "Session goal"\n'
  printf 'priority: normal\n'
  printf '%s\n\n' '---'
  printf 'Goal: %s\n\n' "$goal"
  printf '%s\n' 'References:'
  jq -r '.references[] | "- \(.)"' "$input"
} >"$target/resources/inbox/0001-session-goal.md"
