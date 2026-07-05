#!/usr/bin/env bash
# Materialize the Poisoned-PR CODEX-cell sandbox (full-Codex review team). Reuses the SAME configstore
# PR (feat/file-config, 3 planted defects incl. the path-traversal security hole) as the Claude review
# run — clean cross-family comparison; only the composition differs. Composes both Codex AGENTS.md.
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/poisoned-pr-codex
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/poisoned-pr-codex}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/../../poisoned-pr/fixture/setup-sandbox.sh" "$SB" >/dev/null
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" rev "$SB"
echo
echo "SANDBOX READY (Codex Poisoned-PR cell): $SB"
echo "  rev/   configstore, feat/file-config checked out (prx-rev reviews read-only)"
echo "  sup/   coordinate-only (prx-sup)"
echo "next: ./spin.sh"
