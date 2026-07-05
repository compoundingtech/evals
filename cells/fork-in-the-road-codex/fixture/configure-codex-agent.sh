#!/usr/bin/env bash
# Wire one Fork-in-the-road CODEX-cell agent (full-Codex design panel: fdx-sup + fdx-a/b/c).
# Codex has NO asyncRewake -> wakes via a `ding` SIDECAR. Pre-creates the full coord dir (ding dies on a
# missing folder), pre-trusts the dir in ~/.codex/config.toml (first-run trust gate), and sets a DISTINCT
# per-dir git author = the agent id (the fixture fix — so commit authorship attributes cleanly to the
# owning agent instead of the machine default). Codex persona = AGENTS.md (composed separately); coord MCP
# is the global ~/.codex/config.toml registration (no per-agent .mcp.json).
#   ./configure-codex-agent.sh <sup|a|b|c> [SANDBOX]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/fork-in-the-road-codex}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

case "$role" in
  sup) id="fdx-sup"; d="$SB/sup" ;;   # coordinate-only; writes RECOMMENDATION.md in its own dir
  a)   id="fdx-a";   d="$SB/a" ;;      # champions one approach; writes PROPOSAL.md in its own dir
  b)   id="fdx-b";   d="$SB/b" ;;
  c)   id="fdx-c";   d="$SB/c" ;;
  *) echo "role must be sup|a|b|c" >&2; exit 1 ;;
esac
mkdir -p "$d"

# Pre-trust the dir for Codex (avoids the first-run directory-trust gate blocking unattended launch).
CFG=~/.codex/config.toml
grep -qF "[projects.\"$d\"]" "$CFG" 2>/dev/null || printf '\n[projects."%s"]\ntrust_level = "trusted"\n' "$d" >> "$CFG"

# Pre-create the FULL coord dir (inbox+archive+status) BEFORE launch so ding doesn't die on a missing folder.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# FIXTURE FIX (now.md): distinct git author per agent, so runtime commits attribute to the owning
# identity (the Claude cell all committed as the machine default). setup-sandbox.sh git-inits first, so
# the repo exists here; guard defensively anyway.
if git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$d" config user.name "$id"
  git -C "$d" config user.email "$id@eval.local"
fi

cat > "$d/pty.toml" <<TOML
prefix = "$id"

[sessions.codex]
command = "codex --dangerously-bypass-approvals-and-sandbox"
tags = { role = "agent" }

[sessions.codex.env]
COORD_IDENTITY = "$id"
COORD_ROOT = "$ROOT"
ST_ROOT = "$ROOT"
ST_AGENT = "$id"
ST_IDENTITY = "$id"

# ding = Codex's wake path (no asyncRewake). Watches <id>'s inbox and pokes the <id>-codex session.
[sessions.ding]
command = "coord ding $id-codex --identity $id"
tags = { role = "ding" }

[sessions.ding.env]
COORD_IDENTITY = "$id"
COORD_ROOT = "$ROOT"
TOML

echo "configured $id  (codex + ding->$id-codex, coord dir pre-created, pre-trusted, git author=$id, ephemeral)"
