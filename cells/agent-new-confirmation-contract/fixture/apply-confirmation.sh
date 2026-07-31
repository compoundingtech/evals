#!/usr/bin/env bash
set -euo pipefail

response="${1:?confirm|pending|reject|eof|clean-detach|external-sigint|terminal-ctrl-c required}"
out="${2:?output root required}"
temporary="$out/agents/dev3/global.coding-agents.session-creation.interview-eval"
final="$out/agents/dev3/dotfiles.cos-misc.axe-40.implementation"

mkdir -p "$temporary/resources/axe-agent-new"
cp ./intent.json "$temporary/resources/axe-agent-new/intent"
printf '%s\n' \
  'Identity: dotfiles.cos-misc.axe-40.implementation' \
  'Goal: Implement Axe issue 40 end to end with tests and live verification.' \
  'Trajectory: codex / gpt-5.6-sol / high / generalist' \
  >"$temporary/resources/axe-agent-new/confirmation-summary"

write_temporary() {
  local retired="$1"
  {
    printf '%s\n' 'agent "global.coding-agents.session-creation.interview-eval" {'
    printf '%s\n' '  identity "global.coding-agents.session-creation.interview-eval"'
    printf '%s\n' '  host "dev3"'
    printf '%s\n' '  workspace "/workspace/dotfiles"'
    printf '  retired %s\n' "$retired"
    printf '%s\n' '}'
  } >"$temporary/agent.kdl"
}

write_temporary '#false'
case "$response" in
  confirm)
    write_temporary '#true'
    mkdir -p "$final/resources/inbox"
    printf '%s\n' \
      'agent "dotfiles.cos-misc.axe-40.implementation" {' \
      '  identity "dotfiles.cos-misc.axe-40.implementation"' \
      '  host "dev3"' \
      '  workspace "/workspace/dotfiles"' \
      '  supervisor "dev3.root"' \
      '  argv "/nix/store/axe/bin/axe" "agent" "launch" "--harness" "codex" "--model" "gpt-5.6-sol" "--effort" "high" "--persona" "generalist" "--mode" "managed-unattended" "--boot" "managed-v1"' \
      '}' >"$final/agent.kdl"
    printf '%s\n' \
      'Goal: Implement Axe issue 40 end to end with tests and live verification.' \
      '' \
      'References:' \
      '- https://github.com/compoundingtech/axe/issues/40' \
      >"$final/resources/inbox/0001-session-goal.md"
    printf '%s\n' committed >"$out/outcome"
    ;;
  pending)
    printf '%s\n' awaiting-confirmation >"$out/outcome"
    ;;
  reject|eof)
    write_temporary '#true'
    printf '%s\n' cancelled >"$out/outcome"
    ;;
  clean-detach)
    write_temporary '#true'
    printf '%s\n' cancelled-clean-detach >"$out/outcome"
    ;;
  external-sigint)
    write_temporary '#true'
    printf '%s\n' cancelled-external-sigint-exit-130 >"$out/outcome"
    ;;
  terminal-ctrl-c)
    printf '%s\n' terminal-input-0x03-forwarded >"$out/outcome"
    ;;
  *)
    echo "unsupported confirmation response: $response" >&2
    exit 2
    ;;
esac
