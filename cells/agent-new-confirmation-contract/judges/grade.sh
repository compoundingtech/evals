#!/usr/bin/env bash
set -euo pipefail

mode="${1:?grade mode required}"
root="${CATALOG:?CATALOG required}/out"
temp_rel="agents/dev3/global.coding-agents.session-creation.interview-eval"
final_rel="agents/dev3/dotfiles.cos-misc.axe-40.implementation"

retired() {
  grep -Fqx '  retired #true' "$1/$temp_rel/agent.kdl"
  test -s "$1/$temp_rel/resources/axe-agent-new/intent"
  test -s "$1/$temp_rel/resources/axe-agent-new/confirmation-summary"
}

case "$mode" in
  confirmed)
    out="$root/confirmed"
    retired "$out"
    grep -Fqx committed "$out/outcome"
    test -s "$out/$final_rel/agent.kdl"
    test -s "$out/$final_rel/resources/inbox/0001-session-goal.md"
    ;;
  pending)
    out="$root/pending"
    grep -Fqx '  retired #false' "$out/$temp_rel/agent.kdl"
    grep -Fqx awaiting-confirmation "$out/outcome"
    test ! -e "$out/$final_rel"
    ;;
  cancelled)
    for name in rejected eof; do
      out="$root/$name"
      retired "$out"
      grep -Fqx cancelled "$out/outcome"
      test ! -e "$out/$final_rel"
    done
    out="$root/clean-detach"
    retired "$out"
    grep -Fqx cancelled-clean-detach "$out/outcome"
    test ! -e "$out/$final_rel"
    out="$root/external-sigint"
    retired "$out"
    grep -Fqx cancelled-external-sigint-exit-130 "$out/outcome"
    test ! -e "$out/$final_rel"
    out="$root/terminal-ctrl-c"
    grep -Fqx '  retired #false' "$out/$temp_rel/agent.kdl"
    grep -Fqx terminal-input-0x03-forwarded "$out/outcome"
    test ! -e "$out/$final_rel"
    ;;
  *)
    echo "unknown grade mode: $mode" >&2
    exit 2
    ;;
esac
