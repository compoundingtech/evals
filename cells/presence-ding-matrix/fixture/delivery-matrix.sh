#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
pty_root="$net/pty"
fake_bin="$root/fake-bin"
deliveries="$net/deliveries.log"
ding_log="$root/ding.log"
status_file="$net/agents/dm/target/status"
real_pty="$(command -v pty)"
ding_pid=""

cleanup() {
  if test -n "$ding_pid"; then
    kill "$ding_pid" 2>/dev/null || true
    wait "$ding_pid" 2>/dev/null || true
  fi
  PTY_ROOT="$pty_root" "$real_pty" kill dm.target >/dev/null 2>&1 || true
  PTY_ROOT="$pty_root" "$real_pty" rm dm.target >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for_file() {
  file="$1"
  for _ in $(seq 1 200); do
    if test -s "$file"; then
      return 0
    fi
    sleep 0.05
  done
  printf 'file %s was not populated\n' "$file" >&2
  return 1
}

wait_for_text() {
  marker="$1"
  file="$2"
  for _ in $(seq 1 400); do
    if grep -Fq "$marker" "$file" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
  done
  printf 'text %s did not reach %s\n' "$marker" "$file" >&2
  return 1
}

delivery_count() {
  if test -f "$deliveries"; then
    wc -l <"$deliveries"
  else
    printf '0\n'
  fi
}

send_subject() {
  st2 message send dm.target --catalog "$net" --host dm --as dm.sender \
    --subject "$1" -m "delivery matrix fixture" >/dev/null
}

assert_fifo() {
  first="$(grep -n -m1 -F "$1" "$deliveries" | cut -d: -f1)"
  second="$(grep -n -m1 -F "$2" "$deliveries" | cut -d: -f1)"
  test "$first" -lt "$second"
}

mkdir -p "$fake_bin"
cp "$root/pty-wrapper" "$fake_bin/pty"
chmod +x "$fake_bin/pty"
: >"$deliveries"

PTY_ROOT="$pty_root" "$real_pty" run -d --id dm.target --no-display-name \
  --env CATALOG="$net" -- perl "$net/fake-tui.pl"
wait_for_file "$pty_root/dm.target.pid"

st2 status dm.target --set available --catalog "$net" --host dm --as dm.target >/dev/null
CATALOG="$net" REAL_PTY="$real_pty" PTY_ROOT="$pty_root" PATH="$fake_bin:$PATH" \
  st2 ping dm.target --identity dm.target --catalog "$net" --host dm --interval 50 \
  >"$ding_log" 2>&1 &
ding_pid="$!"
wait_for_text 'ready — found 0 existing unread message(s)' "$ding_log"

st2 status dm.target --set busy --catalog "$net" --host dm --as dm.target >/dev/null
send_subject busy-delivery-b60d
wait_for_text busy-delivery-b60d "$deliveries"
test "$(delivery_count)" -eq 1
echo "BUSY-DELIVERY-GREEN-b60d"

st2 status dm.target --set away --catalog "$net" --host dm --as dm.target >/dev/null
send_subject away-delivery-b60d
wait_for_text away-delivery-b60d "$deliveries"
test "$(delivery_count)" -eq 2
echo "AWAY-DELIVERY-GREEN-b60d"

st2 status dm.target --set dnd --catalog "$net" --host dm --as dm.target >/dev/null
send_subject dnd-fifo-one-b60d
sleep 0.02
send_subject dnd-fifo-two-b60d
sleep 1
test "$(delivery_count)" -eq 2
echo "FRESH-DND-SUPPRESSED-b60d"

touch -d '20 minutes ago' "$status_file"
test "$(st2 status dm.target --catalog "$net" --host dm --as dm.target)" = unknown
wait_for_text dnd-fifo-one-b60d "$deliveries"
wait_for_text dnd-fifo-two-b60d "$deliveries"
assert_fifo dnd-fifo-one-b60d dnd-fifo-two-b60d
echo "STALE-DND-FIFO-GREEN-b60d"

st2 status dm.target --set busy --catalog "$net" --host dm --as dm.target >/dev/null
: >"$net/fail-send"
send_subject failed-head-b60d
sleep 0.02
send_subject after-failed-head-b60d
wait_for_text 'injected send failure' "$ding_log"
test "$(delivery_count)" -eq 4
unlink "$net/fail-send"
wait_for_text failed-head-b60d "$deliveries"
wait_for_text after-failed-head-b60d "$deliveries"
assert_fifo failed-head-b60d after-failed-head-b60d
echo "FAILED-HEAD-RETRY-GREEN-b60d"

kill "$ding_pid"
wait "$ding_pid" 2>/dev/null || true
ding_pid=""
PTY_ROOT="$pty_root" "$real_pty" kill dm.target >/dev/null
PTY_ROOT="$pty_root" "$real_pty" rm dm.target >/dev/null 2>&1 || true
trap - EXIT
test "$(PTY_ROOT="$pty_root" "$real_pty" list --json | jq '[.[] | select(.name == "dm.target" and .status == "running")] | length')" -eq 0
echo "DING-MATRIX-CLEANUP-GREEN-b60d"
