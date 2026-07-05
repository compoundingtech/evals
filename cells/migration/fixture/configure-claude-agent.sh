#!/usr/bin/env bash
# Wire one Migration Claude eval agent: coord MCP (channel) + asyncRewake wake hook + pty.toml
# (HB-3 identity env, ST_ROOT/COORD_ROOT) + pre-created coord dir + bootstrap session jsonl.
# Permission POSTURE (the operator): SUPERVISOR = bypassPermissions (spawn-capable); WORKER = auto.
#   ./configure-claude-agent.sh <sup|dev> [SANDBOX]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/migration}"
HOOKS="${ST_HOOKS_DIR:?set ST_HOOKS_DIR to <smalltalk>/examples/claude-code/hooks}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

case "$role" in
  sup) id="mig-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  dev) id="mig-dev"; d="$SB/worker"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac
sid="$(uuidgen | tr 'A-Z' 'a-z')"

# Pre-trust the dir for Claude Code so `claude --print`/launch don't block on the folder-trust gate.
python3 - "$d" <<'PY'
import json,sys
p="$HOME/.claude.json"; d=json.load(open(p))
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Pre-create the FULL coord dir (inbox+archive+status) so the boot ritual doesn't rabbit-hole.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"
mkdir -p "$d/.claude"; printf '%s\n' "$sid" > "$d/.claude-session-id"

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
command = "claude --permission-mode $mode --dangerously-load-development-channels server:st --resume $sid"
tags = { role = "agent" }

[sessions.claude.env]
ST_AGENT = "$id"
COORD_IDENTITY = "$id"
ST_IDENTITY = "$id"
ST_ROOT = "$ROOT"
COORD_ROOT = "$ROOT"
TOML

( cd "$d" && timeout 90 env ST_AGENT="$id" claude --print --session-id "$sid" "session init" >/dev/null 2>&1 ) \
  && echo "  bootstrapped jsonl" || echo "  (bootstrap best-effort/timed out; continuing)"

echo "configured $id  (sid=$sid, claude --permission-mode $mode, asyncRewake, pre-trusted, coord dir pre-created)"
