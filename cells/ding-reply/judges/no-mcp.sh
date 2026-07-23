#!/usr/bin/env bash
# JUDGE: no MCP — the agent has no .mcp.json anywhere in its world (ding + st2 CLI only, the MCP-less config).
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
found="$(find "$ROOT/work" -name '.mcp.json' 2>/dev/null | head -1)"
[ -z "$found" ] && { echo "PASS: no .mcp.json — ding + st2 CLI only (no MCP)"; exit 0; } \
                || { echo "FAIL: found an .mcp.json ($found) — this cell must be MCP-less"; exit 1; }
