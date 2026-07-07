#!/usr/bin/env bash
# Wire one Poisoned-PR CODEX-cell agent. Codex wakes via a `ding` sidecar; pre-creates the coord dir +
# pre-trusts the dir in ~/.codex/config.toml (before launch) so no first-run trust gate blocks.
#   ./configure-codex-agent.sh <sup|rev> [SANDBOX]
set -euo pipefail
STEV_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$STEV_HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/poisoned-pr-codex}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"
case "$role" in
  sup) id="prx-sup"; d="$SB/sup" ;;
  rev) id="prx-rev"; d="$SB/rev" ;;
  *) echo "role must be sup|rev" >&2; exit 1 ;;
esac
mkdir -p "$d"
CFG=~/.codex/config.toml
grep -qF "[projects.\"$d\"]" "$CFG" 2>/dev/null || printf '\n[projects."%s"]\ntrust_level = "trusted"\n' "$d" >> "$CFG"
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

[sessions.ding]
command = "coord ding $id-codex --identity $id"
tags = { role = "ding" }

[sessions.ding.env]
COORD_IDENTITY = "$id"
COORD_ROOT = "$ROOT"
TOML
echo "configured $id  (codex + ding, coord dir pre-created, pre-trusted)"
