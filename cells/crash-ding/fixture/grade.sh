#!/usr/bin/env bash
# Grade crash-ding (WORKER path) for ONE harness on REAL BUS STATE — the delivered st-message files. Hard gates:
#   REAL CRASH   — convoy up recorded a worker_crash for cd-wk (its non-permanent session actually died).
#   POSITIVE     — a "worker crash: cd-wk" ding FROM convoy-up is in BOTH cd-cos's and cd-sup's inbox.
#   NEGATIVE     — the clean-exit worker cd-clean produced NO "worker crash: cd-clean" ding anywhere (exit 0 = silent).
#   ISOLATION    — nothing leaked to the global pty root.
#   ./grade.sh <codex|claude> [SANDBOX_BASE]
set -uo pipefail
H="${1:?usage: grade.sh <codex|claude> [SANDBOX_BASE]}"
BASE="${2:-${EVAL_SANDBOX:-/tmp}/cd}"
SB="$BASE-$H"; NET="$SB/net"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
[ -f "$SB/.run" ] || { echo "no run at $SB — did spin run for $H?"; exit 1; }

# is <file> a convoy-up "worker crash: <id>" ding? (subject may be quoted)
is_worker_ding() { # <file> <id>
  local f="$1" id="$2"; [ -f "$f" ] || return 1
  grep -qiE '^from:[[:space:]]*"?convoy-up' "$f" && grep -qiE "^subject:[[:space:]]*\"?worker crash:[[:space:]]*$id" "$f"
}
# does <identity>'s inbox contain a worker-crash ding for <id>?
inbox_has_worker_ding() { # <identity> <id>
  local box="$1" id="$2" f
  for f in "$NET/$box/inbox"/*.md; do [ -e "$f" ] || continue; is_worker_ding "$f" "$id" && return 0; done
  return 1
}
# any worker-crash ding for <id> in ANY member inbox?
any_ding_for() { # <id>
  local id="$1" box f
  for box in "$NET"/*/inbox; do [ -d "$box" ] || continue; for f in "$box"/*.md; do [ -e "$f" ] || continue; is_worker_ding "$f" "$id" && return 0; done; done
  return 1
}

echo "== REAL CRASH (hard — convoy up saw cd-wk's non-permanent session die) =="
if grep -qE '"type":"worker_crash".*"(session|identity)":"(silber\.)?cd-wk' "$SB/.events.log" 2>/dev/null; then ok "convoy up recorded a worker_crash for cd-wk (real session death, detect-only, no respawn)"
else no "no worker_crash event for cd-wk — the worker crash was not detected (crash-injection / non-permanent detection wrong)"; fi

echo "== POSITIVE (hard — the worker crash dinged cos AND the supervisor) =="
cos=1; sup=1; inbox_has_worker_ding cd-cos cd-wk && cos=0; inbox_has_worker_ding cd-sup cd-wk && sup=0
if [ "$cos" = 0 ] && [ "$sup" = 0 ]; then ok "a REAL \"worker crash: cd-wk\" ding FROM convoy-up is in BOTH cd-cos's and cd-sup's inbox (whole permanent tier notified)"
elif [ "$cos" = 0 ]; then no "worker-crash ding reached cd-cos but NOT cd-sup (the supervisor was not notified)"
elif [ "$sup" = 0 ]; then no "worker-crash ding reached cd-sup but NOT cd-cos"
else no "NO worker-crash ding delivered after cd-wk crashed — the worker crash->ding path did not fire for harness $H"; fi

echo "== NEGATIVE control (hard — a clean worker exit (code 0) must be SILENT) =="
if any_ding_for cd-clean; then no "FALSE DING: cd-clean exited 0 (clean finish) but got a \"worker crash\" ding — convoy dinged on a routine exit"
else ok "the clean-exit worker cd-clean produced NO ding (exit 0 = silent; the gate distinguishes crash from clean finish)"; fi

echo "== ISOLATION (hard — nothing leaked to the global pty root) =="
leak="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -c 'cd-\(cos\|sup\|wk\|clean\)' || true)"
[ "${leak:-0}" = 0 ] && ok "no cd-* session in the global/prod pty root (isolated net only)" || no "LEAK: cd-* session(s) in the global pty root ($leak)"

echo
echo "SCORE ($H): $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" = 0 ] && echo "==> crash-ding[$H]: PASS — a real $H worker crash dinged cos + the supervisor, and a clean worker exit stayed silent." \
                || echo "==> crash-ding[$H]: FAIL — see the hard-gate failure above."
exit "$fail"
