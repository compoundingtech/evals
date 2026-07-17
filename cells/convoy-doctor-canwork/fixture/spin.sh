#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# spin.sh (convoy-doctor-canwork) — the LIVE CAN-WORK HEADLINE (heavy, gated). Runs `convoy doctor --full` on a
# WELL-FORMED isolated net: preflight passes, then doctor spawns a REAL CoS→supervisor→worker org in its own
# sandbox and grades that they delegated + shipped a graded fix hands-off. HEAVY (real agents, real API, minutes),
# so NOT part of the box-free probe/grade floor; run it explicitly. Writes $SB/.stev/canwork.log for grade.sh.
#
# HARD GATE = the ORG-PROOF CORE (straddle-INDEPENDENT): g1 + cos→sup + sup→wk + graded_fix.
# ADVISORY (straddle-coupled, single-run — NOT gated): rc, the PASS-headline, and the restart-straddle. convoy
# confirmed checkFullOrg returns ONE pass/fail for G1..G5, so rc + PASS-headline both FAIL on a straddle flake —
# gating on them would make the eval flaky. Promote rc + headline + straddle to gates once convoy makes the
# straddle deterministic.
#
# MARKERS: interim = the [full-org] PROSE lines. SWITCH to convoy's stable token line when its follow-up lands:
#   [full-org] GATE g1=pass cos_sup=pass sup_wk=pass graded_fix=pass straddle=pass   (straddle: pass|fail|skip)
# Scoped + torn down; never touches the live fleet.
#   ./spin.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdc}"
mkdir -p "$SB/.stev"
LOG="$SB/.stev/canwork.log"; : > "$LOG"
OUT="$SB/.stev/full.out"
cv(){ env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy "$@"; }

command -v convoy >/dev/null 2>&1 || { echo "orgcore=skip reason=no-convoy" > "$LOG"; echo "SKIP: no convoy"; exit 0; }

mega="$SB/mega"; net="$SB/well"
if [ ! -d "$net" ]; then
  mkdir -p "$mega"; git -C "$mega" init -q; git -C "$mega" config user.email m@e.l; git -C "$mega" config user.name m
  printf '# megarepo\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m seed
  cv init "$net" --megarepo "$mega" --quiet >/dev/null 2>&1
fi

echo "== convoy doctor --full --network <well-formed net> (real CoS→sup→worker graded org proof; heavy) =="
trap 'cv down "$net" --force >/dev/null 2>&1 || true' EXIT INT TERM
if [ "${EVAL_REUSE:-}" = 1 ] && [ -s "$OUT" ]; then
  rc="$(cat "$SB/.stev/full.rc" 2>/dev/null || echo 0)"
  echo "REUSE=1: re-parsing existing $OUT (rc=$rc) — no new doctor --full run (grep-tuning without a heavy re-run)"
else
  cv doctor --full --network "$net" > "$OUT" 2>&1; rc=$?
  echo "$rc" > "$SB/.stev/full.rc"
fi

# ── ORG-PROOF CORE (HARD gate, straddle-independent) — parse the [full-org] markers. ──
# STABLE-TOKEN path (preferred, once convoy's follow-up lands): a single line
#   [full-org] GATE g1=pass cos_sup=pass sup_wk=pass graded_fix=pass straddle=pass
tok(){ sed -n 's/.*\[full-org\] GATE .*'"$1"'=\([a-z]*\).*/\1/p' "$OUT" | tail -1; }
if grep -q '\[full-org\] GATE ' "$OUT"; then
  g1="$(tok g1)"; cos_sup="$(tok cos_sup)"; sup_wk="$(tok sup_wk)"; graded_fix="$(tok graded_fix)"; straddle="$(tok straddle)"
  src=token
else
  # INTERIM prose markers (tolerant .{0,3} spans tolerate the → arrow vs -> vs a space).
  g1=fail;         grep -qiE '\[full-org\] cos available \(hands-off boot' "$OUT" && g1=pass
  cos_sup=fail;    grep -qiE 'cos.{0,3}sup=true' "$OUT" && cos_sup=pass
  sup_wk=fail;     grep -qiE 'sup.{0,3}wk=true'  "$OUT" && sup_wk=pass
  graded_fix=fail; grep -qiE 'graded.fix=true'   "$OUT" && graded_fix=pass
  straddle=skip;   grep -qiE 'straddled=true' "$OUT" && straddle=pass
                   grep -qiE 'reconstructed=false|straddled=false' "$OUT" && straddle=fail
  src=prose
fi
: "${g1:=fail}"; : "${cos_sup:=fail}"; : "${sup_wk:=fail}"; : "${graded_fix:=fail}"; : "${straddle:=skip}"
orgcore=fail
[ "$g1" = pass ] && [ "$cos_sup" = pass ] && [ "$sup_wk" = pass ] && [ "$graded_fix" = pass ] && orgcore=pass

# ── PRIMARY (post-#28: DETERMINISTIC — the straddle no longer gates rc/headline, so these are HARD gates). ──
headline=absent
grep -qiE 'the full autonomous org works on this machine' "$OUT" && headline=pass
[ "$headline" = pass ] || { grep -qiE 'full-org check\(s\) failed' "$OUT" && headline=fail; }
prod=no; grep -qiE 'prod untouched' "$OUT" && prod=yes

{
  echo "orgcore=$orgcore src=$src g1=$g1 cos_sup=$cos_sup sup_wk=$sup_wk graded_fix=$graded_fix"
  echo "primary rc=$rc headline=$headline prod=$prod"
  echo "advisory straddle=$straddle"
} > "$LOG"
sed 's/^/     /' "$LOG"
echo "GRADE: $HERE/grade.sh \"$SB\""
