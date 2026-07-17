#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# spin.sh (convoy-doctor-teardown) — the ABORT test (heavy, gated). Guards convoy #67 (the abort trap): a
# SIGTERM/SIGINT-killed `convoy doctor --full` must run its finally-teardown BEFORE exit, so a CI-timeout-killed
# run does NOT leak its real CoS→sup→worker org (agents + ding sidecars) into a now-deleted sandbox. Pre-#67 a
# killed --full leaked the whole org (observed for real: a run-#1 timeout leaked 5 sessions in cvd-full-gYnbzd);
# #67 traps SIGTERM/SIGINT (suite.ts: "SIGTERM received — tearing down the sandbox org before exit…") + convoy-downs
# the sandbox. (A NORMAL exit + a plain `convoy down` already reap the org+ding — that's not the gap; the ABORT path
# where the finally never runs is. convoy #30 confirmed.)
#
# Flow (ONE real --full; grades on TEARDOWN, never rc — rc is an impl detail):
#   1. launch `convoy doctor --full` in the bg (convoy is a node script, so SIGTERM $! reaches the trap).
#   2. WAIT for the org-up marker "[full-org] real chief-of-staff spawned; convoy up hosting" (earliest a real org
#      exists to leak) + a short settle until the CoS agent/ding is actually live in the sandbox.
#   3. count the sandbox's live org sessions BEFORE the abort — MUST be >0 (a real org is live + the detector is not
#      vacuously always-0). This is the mutation-validity: live-before vs reaped-after, self-contained on one convoy.
#   4. SIGTERM the --full (the CI-timeout abort).
#   5. count AFTER — MUST be 0 + the sandbox swept (the #67 trap reaped the org).
#   6. GUARANTEED self-cleanup of ANY residual leak (so a RED never leaves stragglers) + isolation.
#   ./spin.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdt}"
mkdir -p "$SB/.stev"
LOG="$SB/.stev/teardown.log"; : > "$LOG"
OUT="$SB/.stev/full.out"
cv(){ env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy "$@"; }
CVDROOT="$(cd "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P || echo /tmp)"

command -v convoy >/dev/null 2>&1 || { echo "org_up=skip reason=no-convoy" > "$LOG"; echo "SKIP: no convoy"; exit 0; }

# count LIVE org sessions (agents + ding sidecars) belonging to a given sandbox dir — ps (live procs referencing the
# sandbox) is primary; the sandbox's own pty root is corroboration. Never counts the real fleet (scoped to the dir).
count_org(){
  local sbx="$1"; [ -n "$sbx" ] && [ -d "$sbx" ] || { echo 0; return; }
  local np pp
  np=$(ps -eo command 2>/dev/null | grep -F "$sbx" | grep -v grep | grep -cE 'ding |claude ' || true)
  pp=$(PTY_ROOT="$sbx/n/pty" pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'role=agent|role=ding' | grep -vc 'exited' || true)
  echo $(( np > pp ? np : pp ))
}

mega="$SB/mega"; net="$SB/well"
if [ ! -d "$net" ]; then
  mkdir -p "$mega"; git -C "$mega" init -q; git -C "$mega" config user.email m@e.l; git -C "$mega" config user.name m
  printf '# megarepo\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m seed
  cv init "$net" --megarepo "$mega" --quiet >/dev/null 2>&1
fi

before_dirs="$(ls -d "$CVDROOT"/cvd-full-* 2>/dev/null | sort || true)"

echo "== launch convoy doctor --full in the background =="
env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy doctor --full --network "$net" > "$OUT" 2>&1 &
DPID=$!
trap 'kill -TERM "$DPID" 2>/dev/null; cv down "$net" --force >/dev/null 2>&1 || true' EXIT INT TERM

echo "== wait for the org-up marker (real chief-of-staff spawned), up to 4min =="
org_up=no
for _ in $(seq 1 240); do
  grep -q 'real chief-of-staff spawned' "$OUT" 2>/dev/null && { org_up=yes; break; }
  kill -0 "$DPID" 2>/dev/null || { echo "   doctor --full exited before org-up"; break; }
  sleep 1
done

# identify THIS run's cvd-full sandbox (the dir that appeared since the snapshot)
after_dirs="$(ls -d "$CVDROOT"/cvd-full-* 2>/dev/null | sort || true)"
mysbx="$(comm -13 <(printf '%s\n' "$before_dirs") <(printf '%s\n' "$after_dirs") 2>/dev/null | grep . | tail -1 || true)"
[ -n "$mysbx" ] || mysbx="$(ls -dt "$CVDROOT"/cvd-full-* 2>/dev/null | head -1)"
echo "   this run's sandbox: ${mysbx:-<none>}"

echo "== settle: wait until the CoS agent/ding is LIVE in the sandbox (up to 25s) =="
before_leak=0
for _ in $(seq 1 25); do before_leak="$(count_org "$mysbx")"; [ "${before_leak:-0}" -gt 0 ] && break; sleep 1; done
echo "   before_leak (live org sessions BEFORE abort) = $before_leak"

echo "== SIGTERM the doctor --full (the abort) =="
aborted=no
if [ "$org_up" = yes ] && kill -0 "$DPID" 2>/dev/null; then kill -TERM "$DPID" 2>/dev/null && aborted=yes; fi
wait "$DPID" 2>/dev/null; abort_rc=$?

echo "== wait for the #67 trap teardown (up to 90s) =="
trap_fired=no; grep -qiE 'received — tearing down|received .* tearing down' "$OUT" 2>/dev/null && trap_fired=yes
after_leak="$(count_org "$mysbx")"
for _ in $(seq 1 90); do after_leak="$(count_org "$mysbx")"; [ "${after_leak:-0}" = 0 ] && break; sleep 1; done
torn_down=no; { [ -z "$mysbx" ] || [ ! -d "$mysbx/n" ]; } && torn_down=yes
echo "   after_leak (live org sessions AFTER abort) = $after_leak ; sandbox torn down = $torn_down ; trap_fired=$trap_fired"

echo "== GUARANTEED self-cleanup of any residual leak (so a RED never leaves stragglers) =="
cleaned=no
if [ "${after_leak:-0}" != 0 ] || { [ -n "$mysbx" ] && [ -d "$mysbx/n" ]; }; then
  [ -n "$mysbx" ] && cv down "$mysbx/n" --force >/dev/null 2>&1 || true
  for pid in $(ps -eo pid,command 2>/dev/null | grep -F "$mysbx" | grep -v grep | awk '{print $1}'); do kill -TERM "$pid" 2>/dev/null || true; done
  sleep 3; cleaned=yes
fi
after_clean="$(count_org "$mysbx")"

{
  echo "org_up=$org_up aborted=$aborted trap_fired=$trap_fired marker=chief-of-staff-spawned"
  echo "before_leak=$before_leak after_leak=$after_leak torn_down=$torn_down abort_rc=$abort_rc"
  echo "cleaned=$cleaned after_clean=${after_clean:-0} sandbox=$(basename "${mysbx:-none}")"
} > "$LOG"
sed 's/^/     /' "$LOG"

trap - EXIT INT TERM
cv down "$net" --force >/dev/null 2>&1 || true
echo "GRADE: $HERE/grade.sh \"$SB\""
