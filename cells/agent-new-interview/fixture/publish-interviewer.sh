#!/usr/bin/env bash
set -euo pipefail

profile="${AGENT_RUNTIME_PROFILE:-$HOME/.config/coding-agents/profile.json}"
case "$profile" in
  /*) ;;
  *)
    echo "runtime profile must be absolute: $profile" >&2
    exit 1
    ;;
esac

adapter="$(jq -er '.agentSpec.adapterBin | select(type == "string" and startswith("/"))' "$profile")"
persona_source="$(jq -er '.personas.prompts.generalist | select(type == "string" and startswith("/"))' "$profile")"
for path in "$profile" "$adapter" "$persona_source"; do
  case "$path" in
    *[!A-Za-z0-9_./+-]*)
      echo "runtime path cannot be represented in canonical KDL: $path" >&2
      exit 1
      ;;
  esac
done

mkdir -p ./agents/evalhost/interviewer ./_templates
cp "$persona_source" ./_templates/generalist.md
sed \
  -e "s|@PROFILE@|$profile|" \
  -e "s|@ADAPTER@|$adapter|" \
  ./agent.kdl.template >./agents/evalhost/interviewer/agent.kdl
