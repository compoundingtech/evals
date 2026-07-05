#!/usr/bin/env bash
# Wire the Claude supervisor (mix-sup): coord MCP (channel) + asyncRewake wake hook +
# pty.toml (with HB-3 COORD_IDENTITY env) + bootstrap session jsonl. Ephemeral tags.
#   ./configure-claude-agent.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"
id="mix-sup"; d="$SB/sup"
HOOKS="${ST_HOOKS_DIR:?set ST_HOOKS_DIR to <smalltalk>/examples/claude-code/hooks}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"
sid="$(uuidgen | tr 'A-Z' 'a-z')"
# Pre-create the FULL coord dir (inbox+archive+status). coord_msg_send makes only inbox/, and the
# boot ritual's `coord status --set available` needs archive/ too — otherwise the sup rabbit-holes
# on boot trying to mkdir its own coord folder (license-mit Mixed run finding).
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"
mkdir -p "$d/.claude"
printf '%s\n' "$sid" > "$d/.claude-session-id"

cat > "$d/.mcp.json" <<JSON
{
  "mcpServers": {
    "coord": { "type": "stdio", "command": "$(command -v coord || echo coord)", "args": ["mcp", "--channel"], "env": {} }
  }
}
JSON

cat > "$d/.claude/settings.local.json" <<JSON
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "enabledMcpjsonServers": ["coord"],
  "enableAllProjectMcpServers": true,
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "$HOOKS/session-start.sh", "async": true, "asyncRewake": true }] }],
    "StopFailure": [{ "hooks": [{ "type": "command", "command": "$HOOKS/stop-failure.sh" }] }]
  }
}
JSON

cat > "$d/pty.toml" <<TOML
prefix = "$id"

[sessions.claude]
command = "claude --permission-mode auto --dangerously-load-development-channels server:st --resume $sid"
tags = { role = "agent" }

[sessions.claude.env]
ST_AGENT = "$id"
COORD_IDENTITY = "$id"
ST_IDENTITY = "$id"
ST_ROOT = "$ROOT"
COORD_ROOT = "$ROOT"
TOML

( cd "$d" && ST_AGENT="$id" claude --print --session-id "$sid" "session init" >/dev/null 2>&1 ) \
  && echo "  bootstrapped jsonl" || echo "  (bootstrap best-effort; continuing)"

echo "configured $id  (sid=$sid, claude, asyncRewake hook, ephemeral)"
