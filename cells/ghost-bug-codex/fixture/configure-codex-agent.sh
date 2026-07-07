#!/usr/bin/env bash
# Wire one Ghost-bug CODEX-cell agent (full-Codex debug team). Codex has no asyncRewake -> wakes via a
# `ding` SIDECAR. Pre-creates the full coord dir (ding dies on a missing folder) and pre-trusts the dir
# in ~/.codex/config.toml so the first-run trust gate doesn't block. Codex persona = AGENTS.md (composed
# separately); coord MCP is the global ~/.codex/config.toml registration.
#   ./configure-codex-agent.sh <sup|fix> [SANDBOX]
set -euo pipefail
STEV_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$STEV_HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

case "$role" in
  sup) id="gbx-sup"; d="$SB/sup" ;;
  fix) id="gbx-fix"; d="$SB/worker" ;;
  *) echo "role must be sup|fix" >&2; exit 1 ;;
esac
mkdir -p "$d"

# Pre-trust the dir for Codex (avoids the first-run directory-trust gate blocking unattended launch).
CFG=~/.codex/config.toml
grep -qF "[projects.\"$d\"]" "$CFG" 2>/dev/null || printf '\n[projects."%s"]\ntrust_level = "trusted"\n' "$d" >> "$CFG"

# Pre-create the FULL coord dir (inbox+archive+status) BEFORE launch so ding doesn't die on a missing folder.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

stev_init "$(basename "$(dirname "$STEV_HERE")")" "$SB"   # stev-retirement: spin exports the run's PTY_ROOT; `pty up` lands every session (codex + ding) in it. Plain $id prefix, no stev_prefix/track_extra.
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

echo "configured $id  (codex + ding->$id-codex, coord dir pre-created, pre-trusted, ephemeral)"
