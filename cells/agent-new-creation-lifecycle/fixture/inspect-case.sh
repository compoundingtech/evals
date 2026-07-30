#!/usr/bin/env bash
set -euo pipefail

scenario="${1:?scenario required}"
out="${2:?output root required}"
temp="$out/catalog/agents/dev3/global.coding-agents.session-creation.interview-eval/agent.kdl"
final_root="$out/catalog/agents/dev3/dotfiles.cos-misc.axe-40.implementation"
trace="$out/trace.tsv"

test -f "$temp"
test -f "$trace"
test "$(find "$final_root" -type f -name agent.kdl 2>/dev/null | wc -l)" -le 1
test "$(find "$final_root/resources/inbox" -type f 2>/dev/null | wc -l)" -le 1

case "$scenario" in
  cancel)
    grep -Fqx '  retired #true' "$temp"
    test ! -e "$final_root"
    ;;
  process-crash-before-intent)
    grep -Fqx '  retired #false' "$temp"
    test ! -e "$final_root"
    ;;
  *)
    grep -Fqx '  retired #true' "$temp"
    test -s "$final_root/agent.kdl"
    test "$(find "$final_root/resources/inbox" -type f | wc -l)" -eq 1
    grep -Fqx $'main-pty-absent\ttrue' "$trace"
    grep -Fqx $'ding-state\tindeterminate' "$trace"
    grep -Fqx $'attached\tdev3.dotfiles.cos-misc.axe-40.implementation' "$trace"
    ;;
esac

if [ "$scenario" = concurrent-resume ]; then
  grep -Fqx $'second-invocation\tbusy-no-write-no-attach' "$trace"
  grep -Fqx $'owner-death\treleased' "$trace"
  grep -Fqx $'later-retry\tresumed' "$trace"
fi
