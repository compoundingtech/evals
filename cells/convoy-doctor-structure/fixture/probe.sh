#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-doctor-structure) — DETERMINISTIC, box-free (structure half). Proves the redesign's NARRATED
# `convoy doctor` Structure section (redesign #6, convoy #61/6d3d36c) actually checks the new layout and PASSES on
# a well-formed net + FAILS on a malformed one (mutation-valid). Captures:
#   well.out/well.exit — `convoy doctor --quick --network <well-formed net>`  (all Structure checks ✓, exit 0)
#   bad.out/bad.exit   — same on a MALFORMED net (worktrees/ removed) (Structure has a ✗, non-zero exit)
#
# ISOLATION: doctor is scoped with `--network <sandbox>` and MY ambient ST_ROOT/PTY_ROOT/CONVOY_NETWORK are unset
# (a bare doctor / ST_ROOT hits the operator's real default network). --quick does NOT spawn agents. The live
# can-work half (--full) is HELD for spin.sh (gated). Never touches the live fleet.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cds}"
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
# Run convoy with a CLEAN env (drop my fleet ST_ROOT/PTY_ROOT/CONVOY_NETWORK) + scope every call with --network.
cv(){ env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy "$@"; }

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/shape.txt"; exit 0
fi
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (ahead of committed sha)"
} > "$P/convoy-version.txt" 2>/dev/null || true

mega="$SB/mega"; mkdir -p "$mega"; git -C "$mega" init -q; git -C "$mega" config user.email m@e.l; git -C "$mega" config user.name m
printf '# megarepo\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m seed
well="$SB/well"; bad="$SB/bad"

echo "== a WELL-FORMED net + a MALFORMED net (worktrees/ removed) =="
cv init "$well" --megarepo "$mega" --quiet > "$P/init.out" 2>&1
cp -R "$well" "$bad"; rm -rf "$bad/worktrees"

echo "== convoy doctor --quick --network <net> on each (scoped; no agent spawn) =="
cv doctor --quick --network "$well" > "$P/well.out" 2>&1; echo "$?" > "$P/well.exit"
cv doctor --quick --network "$bad"  > "$P/bad.out"  2>&1; echo "$?" > "$P/bad.exit"

# Extract just the narrated "Structure" section (from its header to the next top-level section).
sect(){ sed -n '/^Structure —/,/^[A-Za-z][A-Za-z]/p' "$1"; }
sect "$P/well.out" > "$P/well.structure.txt"

echo "== capture the shape =="
{
  grep -q '^Structure —' "$P/well.out" && echo "has_structure_section=yes" || echo "has_structure_section=no"
  # the named structure checks must all be present (narrated)
  for k in 'named network' 'smalltalk/' 'pty/' 'worktrees/' 'host-prefixed bus folders' 'pristine workspaces' 'cold-boot'; do
    grep -qiF "$k" "$P/well.structure.txt" && echo "check_present:$k=yes" || echo "check_present:$k=no"
  done
  # WELL-FORMED: zero ✗ in the Structure section + doctor exit 0.
  wf="$(sect "$P/well.out" | grep -c '✗')"
  echo "well_structure_fail_marks=$wf"
  echo "well_exit=$(cat "$P/well.exit")"
  # MALFORMED (mutation): the Structure section must FLAG the missing worktrees/ (>=1 ✗) + doctor non-zero exit.
  bwt="$(sect "$P/bad.out" | grep -iE 'worktrees/' | grep -c '✗')"
  echo "bad_worktrees_flagged=$bwt"
  echo "bad_exit=$(cat "$P/bad.exit")"
} > "$P/shape.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== teardown the isolated nets =="
cv down "$well" --force >/dev/null 2>&1 || true; cv down "$bad" --force >/dev/null 2>&1 || true

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
