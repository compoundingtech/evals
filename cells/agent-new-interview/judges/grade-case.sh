#!/usr/bin/env bash
set -euo pipefail

case_name="${1:?case name required}"
mode="${2:?grade mode required}"
root="${CATALOG:?CATALOG required}"
result="$root/interviewer/result"
intent="$result/intent.json"
expected="$root/cases/$case_name/expected.json"
constraints="$root/interviewer/hard-constraints.json"

identity="$(jq -er .identity "$expected")"
target="$result/agents/evalhost/$identity"
kdl="$target/agent.kdl"
inbox="$target/resources/inbox/0001-session-goal.md"

case "$mode" in
  structural)
    jq -e '
      type == "object" and
      ((keys | sort) == ([
        "decision", "goal", "identity", "references", "schema", "trajectory"
      ] | sort) or (keys | sort) == ([
        "decision", "goal", "identity", "references", "schema", "supervisor", "trajectory"
      ] | sort)) and
      .schema == "axe.agent-creation-intent.v1" and
      .decision == "commit" and
      (.identity | test("^[a-z0-9-]+\\.[a-z0-9-]+\\.[a-z0-9-]+\\.[a-z0-9-]+$")) and
      (.references | type == "array") and
      (.trajectory | keys | sort) == ([
        "boot", "effort", "harness", "mode", "model", "persona"
      ] | sort) and
      .trajectory.mode == "managed-unattended" and
      .trajectory.boot == "managed-v1" and
      ((has("account") or has("provider_argv") or has("workspace") or has("kdl")) | not)
    ' "$intent" >/dev/null
    jq -e --slurpfile intent "$intent" '
      ((has("harness") | not) or .harness == $intent[0].trajectory.harness) and
      ((has("model") | not) or .model == $intent[0].trajectory.model) and
      ((has("effort") | not) or .effort == $intent[0].trajectory.effort) and
      ((has("persona") | not) or .persona == $intent[0].trajectory.persona) and
      ((has("supervisor") | not) or .supervisor == $intent[0].supervisor)
    ' "$constraints" >/dev/null
    ;;
  semantic)
    jq -e --slurpfile expected "$expected" --argjson intent "$(cat "$intent")" '
      .identity == $expected[0].identity and
      .references == $expected[0].references and
      .trajectory == $expected[0].trajectory and
      ((($expected[0] | has("supervisor")) | not) or
        .supervisor == $expected[0].supervisor) and
      all($expected[0].goalTerms[]; . as $term |
        ($intent.goal | ascii_downcase | contains($term)))
    ' "$intent" >/dev/null
    ;;
  bundle)
    test -s "$kdl"
    grep -Fqx "  identity \"$identity\"" "$kdl"
    grep -Fqx '  host "evalhost"' "$kdl"
    grep -Fqx "  workspace \"$root/interviewer\"" "$kdl"
    harness="$(jq -r .trajectory.harness "$expected")"
    model="$(jq -r .trajectory.model "$expected")"
    effort="$(jq -r .trajectory.effort "$expected")"
    persona="$(jq -r .trajectory.persona "$expected")"
    grep -Fqx "  argv \"/nix/store/axe/bin/axe\" \"agent\" \"launch\" \"--harness\" \"$harness\" \"--model\" \"$model\" \"--effort\" \"$effort\" \"--persona\" \"$persona\" \"--mode\" \"managed-unattended\" \"--boot\" \"managed-v1\"" "$kdl"
    ;;
  inbox)
    test -s "$inbox"
    goal="$(jq -r .goal "$intent")"
    grep -Fqx "Goal: $goal" "$inbox"
    while IFS= read -r reference; do
      grep -Fqx -- "- $reference" "$inbox"
    done < <(jq -r '.references[]' "$intent")
    ;;
  boundary)
    test "$(find "$root/interviewer" -type f -name '*.kdl' | wc -l)" -eq 1
    ! grep -Eq 'argv "(claude|codex|opencode|pi)"|--account|goal|references|github\.com' "$kdl"
    ;;
  *)
    echo "unknown grade mode: $mode" >&2
    exit 2
    ;;
esac
