#!/usr/bin/env bash
set -euo pipefail

case_name="${1:-implementation}"
profile="${AGENT_RUNTIME_PROFILE:-$HOME/.config/coding-agents/profile.json}"
case "$profile" in
  /*) ;;
  *)
    echo "runtime profile must be absolute: $profile" >&2
    exit 1
    ;;
esac

adapter="$(jq -er '.agentSpec.adapterBin | select(type == "string" and startswith("/"))' "$profile")"
persona_source="$(jq -er '.personas.prompts["session-creator"] | select(type == "string" and startswith("/"))' "$profile")"
for path in "$profile" "$adapter" "$persona_source"; do
  case "$path" in
    *[!A-Za-z0-9_./+-]*)
      echo "runtime path cannot be represented in canonical KDL: $path" >&2
      exit 1
      ;;
  esac
done

case "$case_name" in
  implementation|small-fix|investigation|hard-constraint) ;;
  *) echo "unknown paid interview case: $case_name" >&2; exit 2 ;;
esac
mkdir -p ./agents/evalhost/global.coding-agents.session-creation.interview-eval ./_templates
cp "$persona_source" ./_templates/session-creator.md
cp "./cases/$case_name/hard-constraints.json" ./interviewer/hard-constraints.json
sed \
  -e "s|@PROFILE@|$profile|" \
  -e "s|@ADAPTER@|$adapter|" \
  ./agent.kdl.template >./agents/evalhost/global.coding-agents.session-creation.interview-eval/agent.kdl
