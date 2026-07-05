#!/usr/bin/env bash
# Materialize the license-mit CODEX-cell sandbox (full-Codex team: lmc-sup + lmc-worker). Reuses the proven
# `license-mit` widget builder (a widget lib with a PROPRIETARY LICENSE, so MIT is a real change), sets a
# DISTINCT git author for the worker (isolation provable from commit metadata), and composes both Codex
# AGENTS.md. Same task/world as the matrix `license-mit` so the Codex cell is a clean, comparable point.
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/license-mit-codex
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mit-codex}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. widget worker repo (proprietary LICENSE) + sup dir (coordinate-only) — the shared license-mit builder
"$HERE/../../license-mit/fixture/setup-sandbox.sh" "$SB" >/dev/null

# 2. distinct git author for the worker (only the owner may author commits to its repo — so isolation is
#    provable from commit metadata, not merely structural)
git -C "$SB/worker" config user.name  "lmc-worker"
git -C "$SB/worker" config user.email "lmc-worker@eval.local"

# 3. compose both Codex personas (AGENTS.md)
"$HERE/compose-persona.sh" sup    "$SB"
"$HERE/compose-persona.sh" worker "$SB"

echo
echo "SANDBOX READY (Codex license-mit cell): $SB"
echo "  sup/     lmc-sup    (manager persona, coordinate-only, owns NO repo — structural isolation)"
echo "  worker/  lmc-worker (specialist persona, owns the widget repo; distinct git author)"
echo "next: ./spin.sh   (wires codex+ding for both, seeds the kick, pty up)"
