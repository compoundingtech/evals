#!/usr/bin/env bash
# Materialize the Ghost-bug CODEX-cell sandbox (full-Codex debug team). Reuses the SAME labelkit ghost
# bug as the Claude Ghost-bug run (the bug is language-agnostic JS) so this is a clean cross-family
# comparison point — the only variable is the team composition. Then sets a distinct Codex worker git
# author + composes both Codex AGENTS.md.
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. build the labelkit repo (+ sup dir) via the proven Ghost-bug builder
"$HERE/../../ghost-bug/fixture/setup-sandbox.sh" "$SB" >/dev/null

# 2. distinct Codex worker git author (provable isolation from commit metadata)
git -C "$SB/worker" config user.name  "gbx-fix"
git -C "$SB/worker" config user.email "gbx-fix@eval.local"

# 3. compose both Codex personas (AGENTS.md)
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" fix "$SB"

echo
echo "SANDBOX READY (Codex Ghost-bug cell): $SB"
echo "  worker/  labelkit (owned by gbx-fix; GREEN suite, ghost mutation bug; distinct author)"
echo "  sup/     coordinate-only (gbx-sup)"
echo "next: ./spin.sh   (wires codex+ding for both, seeds the kick, pty up)"
