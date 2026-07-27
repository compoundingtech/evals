#!/usr/bin/env bash
set -euo pipefail

catalog="${CATALOG:?CATALOG must be set}/net"
settings="$catalog/workspace/.claude/settings.local.json"
jq -e '
  (.hooks | keys | sort) == ["PreCompact", "SessionStart", "StopFailure"] and
  (.hooks.SessionStart | length) == 1 and
  (.hooks.SessionStart[0].hooks | length) == 1 and
  .hooks.SessionStart[0].hooks[0].async == true and
  .hooks.SessionStart[0].hooks[0].asyncRewake == true and
  (.hooks.PreCompact[0].hooks | length) == 1 and
  (.hooks.StopFailure[0].hooks | length) == 1
' "$settings" >/dev/null

while IFS=$'\t' read -r event expected; do
  command_path="$(jq -r --arg event "$event" '.hooks[$event][0].hooks[0].command' "$settings")"
  test "$(basename "$command_path")" = "$expected"
  test -x "$command_path"
done <<'EOF'
SessionStart	claude-session-start.sh
PreCompact	claude-pre-compact.sh
StopFailure	claude-stop-failure.sh
EOF

echo "PASS: current native Claude hooks are configured once and target installed executables"

settings="$catalog/codex-workspace/.codex/hooks.json"
jq -e '
  (.hooks | keys | sort) == ["PreCompact", "SessionStart", "Stop"] and
  (.hooks.SessionStart | length) == 1 and
  (.hooks.SessionStart[0].hooks | length) == 1 and
  (.hooks.PreCompact[0].hooks | length) == 1 and
  (.hooks.Stop[0].hooks | length) == 1
' "$settings" >/dev/null

while IFS=$'\t' read -r event expected; do
  command_path="$(jq -r --arg event "$event" '.hooks[$event][0].hooks[0].command' "$settings")"
  test "$(basename "$command_path")" = "$expected"
  test -x "$command_path"
done <<'EOF'
SessionStart	codex-session-start.sh
PreCompact	codex-pre-compact.sh
Stop	codex-stop.sh
EOF

echo "PASS: current native Codex hooks are configured once and target installed executables"
