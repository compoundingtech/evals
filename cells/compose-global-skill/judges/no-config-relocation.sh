#!/usr/bin/env bash
# NO CONFIG RELOCATION: the rendered seat uses the DEFAULT config dir — its agent.kdl sets no CLAUDE_CONFIG_DIR and
# its command carries no --config-dir / --disable-slash-commands. Relocating the config dir or disabling slash
# commands is exactly what would hide the user's global ~/.claude/skills from the composed session.
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
kdl="$(ls "$SB"/cat/*/gsw/agent.kdl 2>/dev/null | head -1)"
[ -f "$kdl" ] || { echo "FAIL: no rendered agent.kdl under $SB/cat/*/gsw/ — did the compose step run?"; exit 1; }
grep -qiE 'CLAUDE_CONFIG_DIR' "$kdl" && { echo "FAIL: agent.kdl sets CLAUDE_CONFIG_DIR — relocates the config dir, shadowing the user's global skills"; exit 1; }
grep -qiE -- '--config-dir|--disable-slash-commands' "$kdl" && { echo "FAIL: the seat command relocates the config dir or disables skills"; exit 1; }
echo "PASS: the rendered seat uses the DEFAULT config dir (no CLAUDE_CONFIG_DIR, no --config-dir/--disable-slash-commands) — the user's global skills stay discoverable"
