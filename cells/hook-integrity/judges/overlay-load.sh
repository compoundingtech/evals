#!/usr/bin/env bash
set -euo pipefail

workspace="${CATALOG:?CATALOG must be set}/net/workspace"
test -s "$workspace/.st2/PERSONA.md"
test -s "$workspace/.st2/bus.md"
test "$(grep -Fxc '@../../.st2/PERSONA.md' "$workspace/.claude/rules/st2.md")" -eq 1
test "$(grep -Fxc '@../../.st2/bus.md' "$workspace/.claude/rules/st2.md")" -eq 1
echo "PASS: Claude rules load the catalog-owned persona and st2 bus contract exactly once"

codex_workspace="${CATALOG:?CATALOG must be set}/net/codex-workspace"
test -s "$codex_workspace/AGENTS.md"
grep -Fq '# Codex hook probe' "$codex_workspace/AGENTS.md"
echo "PASS: Codex loads its catalog-owned AGENTS.md contract"
