#!/usr/bin/env bash
# Wire the Codex worker (mix-worker): pty.toml with [sessions.codex] (interactive) +
# [sessions.ding] re-wake (Codex has no asyncRewake hook). COORD_IDENTITY + COORD_ROOT are
# REQUIRED or `coord mcp` hard-exits. Persona is AGENTS.md (already composed). Ephemeral tags.
# Uses the global ~/.codex/config.toml coord MCP registration.
#   ./configure-codex-agent.sh [SANDBOX]
set -euo pipefail
STEV_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$STEV_HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"
id="mix-worker"; d="$SB/worker"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"
# Pre-create the coord dir BEFORE launch so the `ding` wake-sidecar doesn't die on a missing
# folder (it exited code 1 twice in the license-mit Mixed run before the dir existed).
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

stev_init "$(basename "$(dirname "$STEV_HERE")")" "$SB"   # stev-retirement: plain $id prefix (no stev_prefix/track_extra); the matrix driver must export the run's PTY_ROOT (as spin.sh does) so `pty up` isolates every session.
cat > "$d/pty.toml" <<TOML
prefix = "$id"

[sessions.codex]
command = "codex --dangerously-bypass-approvals-and-sandbox"
tags = { role = "agent" }

[sessions.codex.env]
COORD_IDENTITY = "$id"
COORD_ROOT = "$ROOT"

[sessions.ding]
command = "coord ding $id-codex --identity $id"
tags = { role = "ding" }

[sessions.ding.env]
COORD_IDENTITY = "$id"
COORD_ROOT = "$ROOT"
TOML

echo "configured $id  (codex + ding->$id-codex, COORD_ROOT set, ephemeral)"
