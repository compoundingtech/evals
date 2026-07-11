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

# assert a worker's crash dinged BOTH cos and the supervisor
positive() { # <worker-id> <label>
  local id="$1" label="$2" c=1 s=1
  inbox_has_worker_ding cd-cos "$id" && c=0; inbox_has_worker_ding cd-sup "$id" && s=0
  if [ "$c" = 0 ] && [ "$s" = 0 ]; then ok "$label ($id): a REAL \"worker crash: $id\" ding FROM convoy-up is in BOTH cd-cos's and cd-sup's inbox"
  elif [ "$c" = 0 ]; then no "$label ($id): ding reached cd-cos but NOT cd-sup (supervisor not notified)"
  elif [ "$s" = 0 ]; then no "$label ($id): ding reached cd-sup but NOT cd-cos"
  else no "$label ($id): NO worker-crash ding delivered — the crash->ding path did not fire for harness $H"; fi
}

echo "== REAL CRASH (hard — convoy up saw both non-permanent workers die) =="
for id in cd-wk cd-oom; do
  if grep -qE '"type":"worker_crash".*"(session|identity)":"(silber\.)?'"$id"'' "$SB/.events.log" 2>/dev/null; then ok "convoy up recorded a worker_crash for $id (real session death, detect-only, no respawn)"
  else no "no worker_crash event for $id — the crash was not detected (crash-injection / non-permanent detection wrong)"; fi
done

echo "== POSITIVE — a real-harness VANISHED crash AND a nonzero/crash EXIT both ding cos AND the supervisor =="
positive cd-wk  "VANISHED (real $H worker, daemon death)"
positive cd-oom "CRASH-EXIT (synthetic worker, nonzero exit 137 — proves the exitCode!=0 gate branch; a real Case-A OOM lands here too via pty #72)"

echo "== NEGATIVE control (hard — a DETECTED clean worker exit (code 0) must be SILENT) =="
# cd-clean must have been a worker convoy up actually WATCHES — a non-permanent convoy agent (ptyfile.session
# tag) that exited 0 — else "no ding" would be a false pass (invisible, not gated). convoy-claude flagged that
# the ptyfile.session tag is what tick() keys on.
detected="$(python3 -c "import json;d=json.load(open('$SB/.clean.json'));t=d.get('tags',{});print(1 if t.get('ptyfile.session') is not None and t.get('strategy')!='permanent' and d.get('exitCode')==0 else 0)" 2>/dev/null || echo 0)"
if any_ding_for cd-clean; then no "FALSE DING: cd-clean exited 0 (clean finish) but got a \"worker crash\" ding — convoy dinged on a routine exit"
elif [ "$detected" = 1 ]; then ok "cd-clean was a DETECTED convoy worker (ptyfile.session set, non-permanent, exited 0) yet produced NO ding — the gate correctly distinguishes a crash from a clean finish"
else no "NEGATIVE UNVERIFIED: cd-clean produced no ding but wasn't confirmed a detected convoy worker (ptyfile.session/non-permanent/exit0) — silence could be invisibility, a false pass"; fi

echo "== ISOLATION (hard — nothing leaked to the global pty root) =="
leak="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -c 'cd-\(cos\|sup\|wk\|clean\)' || true)"
[ "${leak:-0}" = 0 ] && ok "no cd-* session in the global/prod pty root (isolated net only)" || no "LEAK: cd-* session(s) in the global pty root ($leak)"

echo
echo "SCORE ($H): $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" = 0 ] && echo "==> crash-ding[$H]: PASS — a real $H worker crash dinged cos + the supervisor, and a clean worker exit stayed silent." \
                || echo "==> crash-ding[$H]: FAIL — see the hard-gate failure above."
exit "$fail"
