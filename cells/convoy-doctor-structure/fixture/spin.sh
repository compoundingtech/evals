#!/usr/bin/env bash
# spin.sh (convoy-doctor-structure) — the CAN-WORK half (HELD/gated live headline). Runs `convoy doctor --full`,
# which spawns a REAL CoS→sup→worker org and grades that it can do real work on the new-layout sandbox — the "and
# can do real work" half of the Johannes gate. HEAVY (real agents, real API, slow), so it is NOT part of the
# box-free probe/grade flow; run it explicitly. Scoped with --network + a clean env so it never touches the live
# fleet; torn down. Writes $SB/.stev/canwork.log (canwork=pass|fail) that grade.sh reads.
#   ./spin.sh [SANDBOX]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cds}"
mkdir -p "$SB/.stev"
LOG="$SB/.stev/canwork.log"; : > "$LOG"
cv(){ env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy "$@"; }

command -v convoy >/dev/null 2>&1 || { echo "canwork=skip reason=no-convoy" > "$LOG"; echo "SKIP: no convoy"; exit 0; }

mega="$SB/mega"; net="$SB/well"
if [ ! -d "$net" ]; then
  mkdir -p "$mega"; git -C "$mega" init -q; git -C "$mega" config user.email m@e.l; git -C "$mega" config user.name m
  printf '# megarepo\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m seed
  cv init "$net" --megarepo "$mega" --quiet >/dev/null 2>&1
fi

echo "== convoy doctor --full --network <net> (spawns a real CoS->sup->worker on the isolated new-layout net) =="
trap 'cv down "$net" --force >/dev/null 2>&1 || true' EXIT INT TERM
cv doctor --full --network "$net" > "$SB/.stev/full.out" 2>&1; rc=$?
# doctor --full exits 0 + reports the graded org proof PASS when the CoS->sup->worker loop worked.
if [ "$rc" = 0 ] && grep -qiE 'can do real work|graded.*(pass|✓)|org proof.*(pass|✓)|worker.*(done|✓)' "$SB/.stev/full.out"; then
  echo "canwork=pass" > "$LOG"; echo "CAN-WORK: PASS (see $SB/.stev/full.out)"
else
  echo "canwork=fail rc=$rc" > "$LOG"; echo "CAN-WORK: not proven (rc=$rc) — see $SB/.stev/full.out"
fi
echo "GRADE: $HERE/grade.sh \"$SB\""
