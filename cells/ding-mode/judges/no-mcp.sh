#!/usr/bin/env bash
# JUDGE: no MCP — neither agent dir has an .mcp.json (the team coordinated purely over ding + the st2 CLI).
# (On st2 this is inherently true — there is no MCP — so it verifies the ding-only contract held.)
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
mcp=$(find "$ROOT/worker" "$ROOT/sup" -maxdepth 2 -name '.mcp.json' 2>/dev/null | tr '\n' ' ')
[ -z "$mcp" ] && { echo "PASS: no .mcp.json in either agent dir — joined via ding + the st2 CLI, no MCP"; exit 0; } \
             || { echo "FAIL: an .mcp.json exists ($mcp) — the launch was NOT MCP-less"; exit 1; }
