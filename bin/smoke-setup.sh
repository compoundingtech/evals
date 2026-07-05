#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# smoke-setup — the pre-ship "does the fixture actually materialize?" gate.
#
# The grep-gate proves no PII leaks; only a RUN proves the paths resolve. This
# runs each cell's fixture/setup-sandbox.sh into a THROWAWAY sandbox and asserts
# it exits 0 and leaves a non-empty sandbox. NO agents are launched (setup-only)
# — cheap, offline, no pty / live-bus touch. It catches the broken-cross-cell-path
# class (e.g. `$HERE/../<base>/...` vs `$HERE/../../<base>/fixture/...`) that a
# static grep can never see.
#
#   smoke-setup.sh [cell ...]     # default: every cell with a fixture/setup-sandbox.sh
#
# Needs PERSONAS_DIR (cells compose personas during setup) — auto-provisioned via
# bin/ensure-personas.sh if unset. ST_ROOT + EVAL_SANDBOX are pointed at throwaways
# so nothing touches the operator's live bus or real sandboxes.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# personas (pinned) — cells read their role files from here when composing in setup
if [ -z "${PERSONAS_DIR:-}" ]; then
  PERSONAS_DIR="$("$HERE/ensure-personas.sh" 2>/dev/null)" \
    || { echo "smoke-setup: could not provision personas (bin/ensure-personas.sh failed)" >&2; exit 2; }
fi
export PERSONAS_DIR

# throwaway roots — NEVER the live bus / real sandboxes
TMP="$(mktemp -d "${TMPDIR:-/tmp}/stev-smoke.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export ST_ROOT="$TMP/st-root"; mkdir -p "$ST_ROOT"
export EVAL_SANDBOX="$TMP/sandbox"

# which cells?
if [ "$#" -gt 0 ]; then
  cells=("$@")
else
  cells=()
  for d in "$ROOT"/cells/*/; do
    [ -f "$d/fixture/setup-sandbox.sh" ] && cells+=("$(basename "$d")")
  done
fi

echo "smoke-setup: $(( ${#cells[@]} )) cell(s); personas @ $(git -C "$PERSONAS_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
pass=0; fail=0; skip=0; failed_cells=()
for cell in "${cells[@]}"; do
  s="$ROOT/cells/$cell/fixture/setup-sandbox.sh"
  if [ ! -f "$s" ]; then echo "  SKIP  $cell (no fixture/setup-sandbox.sh)"; skip=$((skip+1)); continue; fi
  sb="$TMP/sandbox/$cell"
  if out="$("$s" "$sb" 2>&1)" && [ -n "$(ls -A "$sb" 2>/dev/null || true)" ]; then
    echo "  PASS  $cell"
    pass=$((pass+1))
  else
    echo "  FAIL  $cell"
    printf '%s\n' "$out" | tail -8 | sed 's/^/          /'
    fail=$((fail+1)); failed_cells+=("$cell")
  fi
done

echo
echo "smoke-setup: $pass passed, $fail failed, $skip skipped"
if [ "$fail" -gt 0 ]; then
  echo "FAILED: ${failed_cells[*]}" >&2
  exit 1
fi
echo "✓ all fixtures materialize (setup resolves + exits 0, non-empty sandbox)"
