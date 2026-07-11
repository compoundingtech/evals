#!/usr/bin/env bash
# Spin the crash-ding WORKER scenario for ONE harness (codex|claude). convoy up (feat/crash-ding, c6ef00c+)
# now also dings on a NON-PERMANENT worker's crash — detect-only (no respawn), gated on the exit:
# nonzero/vanished -> "worker crash: <id>" ding to cos + all permanent supervisors; a CLEAN exit 0 -> SILENT.
# Members: cd-cos (perm cos) + cd-sup (perm supervisor) = the ding recipients; cd-wk (NON-perm REAL --harness
# worker) = the crash target (POSITIVE); cd-clean (NON-perm synthetic `exit 0` worker) = the negative control.
#   ./spin.sh <codex|claude> [SANDBOX_BASE]        # needs CONVOY_BIN (a convoy with the worker-crash ding)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="${1:?usage: spin.sh <codex|claude> [SANDBOX_BASE]}"
BASE="${2:-${EVAL_SANDBOX:-/tmp}/cd}"
CONVOY="${CONVOY_BIN:-convoy}"
SB="$("$HERE/setup-sandbox.sh" "$H" "$BASE" | head -1)"
NET="$SB/net"; PR="$NET/pty"; export ST_ROOT="$NET"
WK="cd-wk"; WK_ID="silber.$WK"; WK_DISP="silber.$WK-$H"
: > "$SB/.events.log"; : > "$SB/.crash.log"

stop_host() { [ -f "$SB/.up.pid" ] && kill "$(cat "$SB/.up.pid")" 2>/dev/null; sleep 1; }
teardown() { stop_host; "$CONVOY" down "$NET" --force >/dev/null 2>&1 || true; }
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down $NET ==" >&2; teardown; }' EXIT
trap 'stop_host; exit 130' INT; trap 'stop_host; exit 143' TERM

snap() { for id in cd-cos cd-sup; do ls "$NET/$id/inbox"/*.md 2>/dev/null > "$SB/.$1.$id" || : > "$SB/.$1.$id"; done; }
sess_up() { pty --root "$PR" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "$WK_DISP .*pid:"; }
wait_up() { local n="${1:-40}"; for _ in $(seq 1 "$n"); do sess_up && return 0; sleep 1; done; return 1; }
# CRASH cd-wk as a HARD DEATH (status "vanished"). Killing the harness CHILD is NOT a crash: SIGTERM -> the
# process shuts down gracefully (exit 0), SIGKILL -> exitCode null — and workerCrashed() needs a NONZERO exit
# OR status "vanished". A real worker can't be made to exit(N), so we simulate the hard death convoy classifies
# as a crash: SIGKILL the pty DAEMON itself (it can't record an exit -> the session is "vanished"), then reap
# the orphaned harness child. DAEMON FIRST — killing the child first would let the daemon record a clean exit.
crash_worker() {
  local pf="$PR/$WK_ID.pid" dpid child
  [ -f "$pf" ] || { echo "no pidfile $pf" >&2; return 1; }
  dpid="$(cat "$pf")"; child="$(pgrep -P "$dpid" 2>/dev/null)"
  kill -9 "$dpid" 2>/dev/null || true               # daemon vanishes -> status "vanished" -> workerCrashed
  [ -n "$child" ] && kill -9 $child 2>/dev/null      # reap the orphaned harness process
  printf 'crashed %s (daemon %s vanished) at %s\n' "$WK_ID" "$dpid" "$(date +%s)" >> "$SB/.crash.log"
}
# NEGATIVE control: a NON-permanent convoy worker that EXITS 0 (clean finish) must NOT ding. convoy add always
# spawns a harness (never exit 0), so hand-write a pty.toml worker + `pty up` it: it carries the ptyfile.session
# tag (from the [sessions.X] key) + ST_AGENT + NO strategy=permanent — exactly what tick() keys a worker on.
spawn_clean_worker() {
  mkdir -p "$SB/clean"
  cat > "$SB/clean/pty.toml" <<TOML
prefix = "silber.cd-clean"
[sessions.clean]
id = "silber.cd-clean"
command = "sh -c 'sleep 4; exit 0'"
[sessions.clean.tags]
role = "agent"
"st.network" = "$NET"
[sessions.clean.env]
ST_AGENT = "cd-clean"
ST_ROOT = "$NET"
PTY_ROOT = "$PR"
TOML
  pty --root "$PR" up "$SB/clean" clean >/dev/null 2>&1 || true
}

echo "== 1/6  convoy init + pretrust ($NET) ==" >&2
"$CONVOY" init "$NET" >/dev/null 2>&1 || { echo "convoy init failed"; exit 1; }
"$CONVOY" pretrust "$SB/cd-cos" "$SB/cd-sup" "$SB/cd-wk" >/dev/null 2>&1 || true
[ "$H" = codex ] && "$CONVOY" pretrust --harness codex "$SB/cd-cos" "$SB/cd-sup" "$SB/cd-wk" >/dev/null 2>&1 || true

echo "== 2/6  compose personas ==" >&2
"$HERE/compose-persona.sh" cos    "cd-cos" "$SB" >/dev/null
"$HERE/compose-persona.sh" sup    "cd-sup" "$SB" >/dev/null
"$HERE/compose-persona.sh" worker "cd-wk"  "$SB" >/dev/null

echo "== 3/6  add cd-cos + cd-sup (PERMANENT recipients) + cd-wk (NON-permanent real $H worker) ==" >&2
"$CONVOY" add cos        --identity cd-cos --permanent --network "$NET" --dir "$SB/cd-cos" --persona "$SB/personas-local/cd-cos.md" >/dev/null 2>&1
"$CONVOY" add supervisor --identity cd-sup --permanent --network "$NET" --dir "$SB/cd-sup" --persona "$SB/personas-local/cd-sup.md" >/dev/null 2>&1
"$CONVOY" add worker     --identity cd-wk               --harness "$H" --network "$NET" --dir "$SB/cd-wk"  --persona "$SB/personas-local/cd-wk.md" >/dev/null 2>&1
mkdir -p "$NET/cd-cos/inbox" "$NET/cd-sup/inbox"

echo "== 4/6  HOST (continuous convoy up, fast reconcile, bg) + spawn the clean-exit worker ==" >&2
"$CONVOY" up "$NET" --reconcile-interval 1 --json >> "$SB/.events.log" 2>&1 &
echo $! > "$SB/.up.pid"
wait_up 40 || { echo "cd-wk never came up under convoy up"; exit 1; }
sleep 2
spawn_clean_worker            # cd-clean will run ~4s then exit 0 -> convoy up must stay SILENT on it
snap before                   # baseline inbox state

echo "== 5/6  CRASH cd-wk (kill its harness child -> nonzero/vanished) -> expect a worker-crash ding ==" >&2
crash_worker
sleep 8                        # let convoy up's reconcile detect the worker gone + ding, and cd-clean exit 0
snap after

echo "== 6/6  stop host + record ==" >&2
stop_host
{ echo "harness=$H"; echo "net=$NET"; echo "worker=$WK"; echo "session=$WK_ID"; echo "clean=cd-clean"; } > "$SB/.run"
echo "$SB"
cat >&2 <<EOF
SPUN (crash-ding WORKER, harness=$H, net=$NET).
  events: $SB/.events.log   (worker_crash JSONL)
  POSITIVE: cd-cos + cd-sup inboxes should hold "worker crash: cd-wk";  NEGATIVE: NO "worker crash: cd-clean".
GRADE:    $HERE/grade.sh "$H" "$BASE"
TEARDOWN: $CONVOY down "$NET" --force
EOF
