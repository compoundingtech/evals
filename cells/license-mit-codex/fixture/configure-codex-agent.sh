#!/usr/bin/env bash
# Wire one license-mit CODEX-cell agent (full-Codex team: lmc-sup + lmc-worker). Codex wakes via a
# `ding` sidecar; pre-creates the coord dir + pre-trusts the dir in ~/.codex/config.toml (before launch)
# so no first-run trust gate blocks. The pty prefix comes from the shared stev harness (collision-proof,
# torn down per run) — never a bare id.
#   ./configure-codex-agent.sh <sup|worker> [SANDBOX]
set -euo pipefail
STEV_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$STEV_HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/license-mit-codex}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"
case "$role" in
  sup)    id="lmc-sup";    d="$SB/sup" ;;      # coordinate-only, owns NO product repo (structural isolation)
  worker) id="lmc-worker"; d="$SB/worker" ;;   # owns the widget repo
  *) echo "role must be sup|worker" >&2; exit 1 ;;
esac
mkdir -p "$d"
CFG=~/.codex/config.toml
grep -qF "[projects.\"$d\"]" "$CFG" 2>/dev/null || printf '\n[projects."%s"]\ntrust_level = "trusted"\n' "$d" >> "$CFG"
# Pre-create the FULL coord dir (inbox+archive+status) so the `ding` wake-sidecar doesn't die on a
# missing folder and the boot ritual's status-set + inbox-drain don't rabbit-hole.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"
stev_init "$(basename "$(dirname "$STEV_HERE")")" "$SB"; pfx="$(stev_prefix "$SB" "$id")"
cat > "$d/pty.toml" <<TOML
prefix = "$pfx"

[sessions.codex]
command = "codex --dangerously-bypass-approvals-and-sandbox"
tags = { role = "agent" }

[sessions.codex.env]
COORD_IDENTITY = "$id"
COORD_ROOT = "$ROOT"
ST_ROOT = "$ROOT"
ST_AGENT = "$id"
ST_IDENTITY = "$id"

# ding = Codex's wake path (no asyncRewake). It watches <id>'s inbox and pokes the codex session.
[sessions.ding]
command = "coord ding $pfx-codex --identity $id"
tags = { role = "ding" }

[sessions.ding.env]
COORD_IDENTITY = "$id"
COORD_ROOT = "$ROOT"
TOML
echo "configured $id  (codex + ding->$pfx-codex, coord dir pre-created, pre-trusted, ephemeral role=agent)"
