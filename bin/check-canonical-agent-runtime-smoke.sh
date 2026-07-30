#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source bin/st2-pin.sh

bin/check-st2-package-provenance.sh
export PATH="$ST2_OUTPUT_PATH/bin:$PATH"

bin/corpus-inventory.sh --no-header |
  awk -F '\t' '$1 == "canonical-agent-runtime-smoke" && $2 == "model-free" && $5 == 0 { found = 1 } END { exit !found }' || {
    echo "FAIL: canonical-agent-runtime-smoke is not classified as zero-model-agent model-free" >&2
    exit 1
  }

log="$(mktemp)"
catalog=""
cleanup() {
  rm -f -- "$log"
  if [ -n "$catalog" ]; then
    case "$catalog" in
      /tmp/st2e-[0-9]*) rm -rf -- "$catalog" ;;
      *) echo "REFUSE: unexpected scratch catalog path $catalog" >&2 ;;
    esac
  fi
}
trap cleanup EXIT

set +e
st2 eval ./cells/canonical-agent-runtime-smoke/ --keep >"$log" 2>&1 &
eval_pid=$!
catalog="/tmp/st2e-$eval_pid"
wait "$eval_pid"
status=$?
set -e
cat "$log"

[ "$status" -eq 0 ] || {
  echo "FAIL: canonical Agent Spec smoke exited $status" >&2
  exit "$status"
}
grep -Fq "SCORE: 9 PASS / 0 FAIL / 9 gating judges" "$log"
grep -Fq "VERDICT: PASS" "$log"

for pid_file in "$catalog/probe/work.pid" "$catalog/probe/guard.pid"; do
  pid="$(cat "$pid_file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || {
    echo "FAIL: canonical runtime task receipt is not a PID: $pid_file=$pid" >&2
    exit 1
  }
  if kill -0 "$pid" 2>/dev/null; then
    echo "FAIL: canonical runtime task $pid from $pid_file survived eval teardown" >&2
    exit 1
  fi
done

sessions="$(st2 pty --catalog "$catalog" ls --json)"
jq -e 'length == 0' <<<"$sessions" >/dev/null || {
  echo "FAIL: canonical eval left PTY registry residue: $sessions" >&2
  exit 1
}
test ! -e "$catalog/REMOTE-SPAWNED"

echo "PASS: path-independent local PTY+exec launched, native routing completed, remote sentinel stayed inert, and teardown left zero tasks"
