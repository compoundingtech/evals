#!/usr/bin/env bash
# Spin the crash-ding WORKER scenario for ONE harness (codex|claude). convoy up dings on a NON-PERMANENT worker
# whose session dies "hard": workerCrashed() = status "vanished" || (status exited && exitCode != 0) — a vanished
# session OR a nonzero exit dings, a clean exit 0 stays SILENT. Proven with a REAL harness worker for the harness-
# agnostic VANISHED path + a deterministic synthetic worker for the exit-code branch (a real agent can't be
# scripted to exit(N)). OOM SCOPE (reconciled w/ pty-claude + convoy-claude; pty #72 merged): Case A = the
# worker's OWN pty-spawned process OOM-killed -> node-pty signal=9 -> pty #72 records exitCode 137 -> the same
# nonzero branch cd-oom proves -> dings (no convoy change). Case B = a grandchild OOM'd while the pty-spawned
# parent reaps it and exits 0 -> byte-identical to a clean exit -> SILENT, a documented blind spot (OS-level).
#   cd-cos + cd-sup (--permanent) = the ding recipients.
#   cd-wk  (NON-perm REAL --harness worker) crashed VANISHED (SIGKILL the pty daemon)              -> ding.
#   cd-oom (NON-perm SYNTHETIC worker, exit 137 — proves exitCode!=0; Case-A OOM lands here via #72) -> ding.
#   cd-clean (NON-perm synthetic worker, exit 0)                                                   -> SILENT (negative).
#   ./spin.sh <codex|claude> [SANDBOX_BASE]        # needs CONVOY_BIN (convoy with the worker-crash ding)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="${1:?usage: spin.sh <codex|claude> [SANDBOX_BASE]}"
BASE="${2:-${EVAL_SANDBOX:-/tmp}/cd}"
CONVOY="${CONVOY_BIN:-convoy}"
SB="$("$HERE/setup-sandbox.sh" "$H" "$BASE" | head -1)"
NET="$SB/net"; PR="$NET/pty"; export ST_ROOT="$NET"
: > "$SB/.events.log"; : > "$SB/.crash.log"

stop_host() { [ -f "$SB/.up.pid" ] && kill "$(cat "$SB/.up.pid")" 2>/dev/null; sleep 1; }
teardown() { stop_host; "$CONVOY" down "$NET" --force >/dev/null 2>&1 || true; }
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down $NET ==" >&2; teardown; }' EXIT
trap 'stop_host; exit 130' INT; trap 'stop_host; exit 143' TERM

snap() { for id in cd-cos cd-sup; do ls "$NET/$id/inbox"/*.md 2>/dev/null > "$SB/.$1.$id" || : > "$SB/.$1.$id"; done; }
sess_up() { pty --root "$PR" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "silber.$1-$H .*pid:"; }
wait_up() { local id="$1" n="${2:-40}"; local _; for _ in $(seq 1 "$n"); do sess_up "$id" && return 0; sleep 1; done; return 1; }
# CRASH the REAL worker cd-wk as a hard death (status "vanished"): SIGKILL the pty DAEMON so no exit is recorded.
crash_vanish() {
  local pf="$PR/silber.cd-wk.pid" dpid child
  [ -f "$pf" ] || { echo "no pidfile $pf" >&2; return 1; }
  dpid="$(cat "$pf")"; child="$(pgrep -P "$dpid" 2>/dev/null)"
  kill -9 "$dpid" 2>/dev/null || true; [ -n "$child" ] && kill -9 $child 2>/dev/null
  printf 'crashed cd-wk (vanished, daemon %s) at %s\n' "$dpid" "$(date +%s)" >> "$SB/.crash.log"
}
# A synthetic NON-permanent convoy worker (ptyfile.session via `pty up`) that runs then exits <code>. Deterministic:
# exit 0 = a clean finish (silent); a nonzero code = an abnormal/crash exit (workerCrashed -> ding). A real Case-A
# OOM reaches this SAME nonzero branch via pty #72 (signal 9 -> exitCode 137).
spawn_synth() { # <id> <exitcode>
  local id="$1" code="$2"
  local d="$SB/$id"                          # SEPARATE line: $id must be the local, not an outer var
  mkdir -p "$d"
  cat > "$d/pty.toml" <<TOML
prefix = "silber.$id"
[sessions.s]
id = "silber.$id"
command = "sh -c 'sleep 4; exit $code'"
[sessions.s.tags]
role = "agent"
"st.network" = "$NET"
[sessions.s.env]
ST_AGENT = "$id"
ST_ROOT = "$NET"
PTY_ROOT = "$PR"
TOML
  pty --root "$PR" up "$d" s >/dev/null 2>&1 || true
}

echo "== 1/6  convoy init + pretrust ($NET) ==" >&2
"$CONVOY" init "$NET" >/dev/null 2>&1 || { echo "convoy init failed"; exit 1; }
"$CONVOY" pretrust "$SB/cd-cos" "$SB/cd-sup" "$SB/cd-wk" >/dev/null 2>&1 || true
[ "$H" = codex ] && "$CONVOY" pretrust --harness codex "$SB/cd-cos" "$SB/cd-sup" "$SB/cd-wk" >/dev/null 2>&1 || true

echo "== 2/6  compose personas ==" >&2
"$HERE/compose-persona.sh" cos    "cd-cos" "$SB" >/dev/null
"$HERE/compose-persona.sh" sup    "cd-sup" "$SB" >/dev/null
"$HERE/compose-persona.sh" worker "cd-wk"  "$SB" >/dev/null

echo "== 3/6  add cd-cos + cd-sup (PERMANENT recipients) + cd-wk (NON-perm real $H worker) ==" >&2
"$CONVOY" add cos        --identity cd-cos --permanent --network "$NET" --dir "$SB/cd-cos" --persona "$SB/personas-local/cd-cos.md" >/dev/null 2>&1
"$CONVOY" add supervisor --identity cd-sup --permanent --network "$NET" --dir "$SB/cd-sup" --persona "$SB/personas-local/cd-sup.md" >/dev/null 2>&1
"$CONVOY" add worker     --identity cd-wk               --harness "$H" --network "$NET" --dir "$SB/cd-wk"  --persona "$SB/personas-local/cd-wk.md" >/dev/null 2>&1
mkdir -p "$NET/cd-cos/inbox" "$NET/cd-sup/inbox"

echo "== 4/6  HOST (continuous convoy up, fast reconcile, bg) + spawn the synthetic crash + clean workers ==" >&2
"$CONVOY" up "$NET" --reconcile-interval 1 --json >> "$SB/.events.log" 2>&1 &
echo $! > "$SB/.up.pid"
wait_up cd-wk 40 || { echo "cd-wk never came up"; exit 1; }
sleep 2
spawn_synth cd-oom   137      # abnormal-exit worker: nonzero exit -> should ding (Case-A OOM lands here via #72)
spawn_synth cd-clean 0        # clean finish: exit 0 -> should stay silent
snap before

echo "== 5/6  CRASH cd-wk (vanished) -> ding; cd-oom exits 137 -> ding; cd-clean exits 0 -> silent ==" >&2
crash_vanish
sleep 9                        # let convoy up detect cd-wk vanished + cd-oom/cd-clean exit, and ding accordingly
snap after

echo "== 6/6  capture clean-exit worker state (non-false-pass) + stop host + record ==" >&2
cp "$PR/silber.cd-clean.json" "$SB/.clean.json" 2>/dev/null || : > "$SB/.clean.json"
cp "$PR/silber.cd-oom.json"   "$SB/.oom.json"   2>/dev/null || : > "$SB/.oom.json"
stop_host
{ echo "harness=$H"; echo "net=$NET"; echo "vanish=cd-wk"; echo "crashexit=cd-oom"; echo "clean=cd-clean"; } > "$SB/.run"
echo "$SB"
cat >&2 <<EOF
SPUN (crash-ding WORKER, harness=$H, net=$NET).
  POSITIVE: cd-cos + cd-sup should hold "worker crash: cd-wk" (vanished, real $H) AND "worker crash: cd-oom" (exit 137).
  NEGATIVE: NO "worker crash: cd-clean" (exit 0).
GRADE:    $HERE/grade.sh "$H" "$BASE"
TEARDOWN: $CONVOY down "$NET" --force
EOF
