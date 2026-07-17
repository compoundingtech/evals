#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-doctor-canwork) — the BOX-FREE floor: `convoy doctor --full` FAILS-CLOSED on a bad preflight.
# The heavy CAN-WORK PASS proof (a real CoS→sup→worker graded org) is the LIVE headline in fixture/spin.sh (gated).
#
# doctor --full runs its PREFLIGHT against --network, then — ONLY if the preflight is all-green — runs the org proof
# in its OWN isolated sandbox (it makes its own; it does NOT use --network for the org proof). So
# `doctor --full --network <MALFORMED>` short-circuits with rc=1 at the preflight, BEFORE any org spawn — a fast,
# box-free, deterministic FAILS-CLOSED negative. Captures:
#   pre.out/pre.rc — doctor --full --network <malformed net>  (expect rc=1, a preflight structure ✗, NO headline)
#
# HONEST SCOPE (labeled, do not overclaim): this proves the PREFLIGHT gate fails-closed, NOT that the org grader
# catches a bad worker fix. The org-grader mutation-validity is convoy's OWN internal ghost-bug + mutation-valid
# grader test (cross-referenced in grade.sh + task.toml), not exercised from outside (external force-bad knob DECLINED by Nathan).
#
# ISOLATION: scoped with --network + ambient ST_ROOT/PTY_ROOT/CONVOY_NETWORK unset. Never touches the live fleet.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdc}"
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
cv(){ env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy "$@"; }

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/shape.txt"; exit 0
fi
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (ahead of committed sha)"
} > "$P/convoy-version.txt" 2>/dev/null || true

# a MALFORMED net: convoy-init a well-formed one, then remove worktrees/ so the preflight structure check fails.
mega="$SB/mega"; bad="$SB/bad"
mkdir -p "$mega"; git -C "$mega" init -q; git -C "$mega" config user.email m@e.l; git -C "$mega" config user.name m
printf '# m\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m seed
cv init "$bad" --megarepo "$mega" --quiet >/dev/null 2>&1
rm -rf "$bad/worktrees"   # break the layout -> preflight structure ✗

echo "== convoy doctor --full --network <MALFORMED> (expect: preflight ✗ short-circuit, rc=1, NO org spawn) =="
cv doctor --full --network "$bad" > "$P/pre.out" 2>&1; echo "$?" > "$P/pre.rc"

echo "== capture the shape =="
{
  echo "pre_rc=$(cat "$P/pre.rc")"
  # a preflight structure ✗ must be present (worktrees/ MISSING)
  grep -qiE 'worktrees/: MISSING|✗ .*worktrees' "$P/pre.out" && echo "pre_preflight_fail=yes" || echo "pre_preflight_fail=no"
  # the can-work headline PASS must NOT appear (org proof never reached)
  grep -qiE 'the full autonomous org works on this machine' "$P/pre.out" && echo "pre_headline_pass=yes" || echo "pre_headline_pass=no"
} > "$P/shape.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\"   (heavy PASS proof: $HERE/spin.sh \"$SB\")"
