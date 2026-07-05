#!/usr/bin/env bash
# Wire a GLM-backed Claude agent = Claude Code harness + glm-5.2:cloud via ollama's local
# Anthropic-compatible endpoint. Mirrors configure-claude-agent.sh + the 7-var ollama launch
# contract + `--model glm-5.2:cloud`. GLM launch is ENV-REPLICATION (no `ollama launch` fight);
# requires `ollama serve` up (:11434). asyncRewake works (Claude harness). Ephemeral tags.
#   ./configure-glm-agent.sh <sup|worker> <ID> [SANDBOX]
set -euo pipefail
role="$1"; id="$2"; SB="${3:-${EVAL_SANDBOX:-./.sandbox}/license-glm}"
HOOKS="${ST_HOOKS_DIR:?set ST_HOOKS_DIR to <smalltalk>/examples/claude-code/hooks}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"
case "$role" in
  sup)    d="$SB/sup";    perm="bypassPermissions" ;;   # sup coordinates; bypass = low-touch
  worker) d="$SB/worker"; perm="auto" ;;
  *) echo "role must be sup|worker" >&2; exit 1 ;;
esac
sid="$(uuidgen | tr 'A-Z' 'a-z')"
# Pre-create the FULL coord dir (inbox+archive+status) — boot ritual's `coord status` needs archive/.
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

# pty.toml — the GLM env contract is the ONLY delta from a normal Claude cell.
cat > "$d/pty.toml" <<TOML
prefix = "$id"

[sessions.claude]
command = "claude --permission-mode $perm --dangerously-load-development-channels server:st --model glm-5.2:cloud --resume $sid"
tags = { role = "agent" }

[sessions.claude.env]
ST_AGENT = "$id"
COORD_IDENTITY = "$id"
ST_IDENTITY = "$id"
ST_ROOT = "$ROOT"
COORD_ROOT = "$ROOT"
ANTHROPIC_BASE_URL = "http://127.0.0.1:11434"
ANTHROPIC_AUTH_TOKEN = "ollama"
ANTHROPIC_API_KEY = ""
ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-5.2:cloud"
ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5.2:cloud"
ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-5.2:cloud"
CLAUDE_CODE_SUBAGENT_MODEL = "glm-5.2:cloud"
TOML

# Distinct git author for the worker -> isolation provable from commit metadata (not just structural).
if [ "$role" = "worker" ]; then
  git -C "$d" config user.name "$id"
  git -C "$d" config user.email "$id@eval.local"
  echo "  worker git author set: $id <$id@eval.local>"
fi

# Bootstrap the resume jsonl ON GLM (doubles as a per-agent end-to-end GLM proof).
( cd "$d" && env \
    ANTHROPIC_BASE_URL=http://127.0.0.1:11434 ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY= \
    ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-5.2:cloud ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.2:cloud \
    ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5.2:cloud CLAUDE_CODE_SUBAGENT_MODEL=glm-5.2:cloud \
    ST_AGENT="$id" timeout 150 claude --print --model glm-5.2:cloud --session-id "$sid" "reply OK" >/dev/null 2>&1 ) \
  && echo "  bootstrapped jsonl on GLM" || echo "  (GLM bootstrap best-effort; continuing)"

echo "configured $id  (GLM/claude, perm=$perm, --model glm-5.2:cloud, asyncRewake, ephemeral, sid=$sid)"
