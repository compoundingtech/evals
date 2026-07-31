#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
package_root="${EVALS_PTY_PR133_ROOT:?EVALS_PTY_PR133_ROOT must point to exact PTY head}"
expected_st2="c6846f6239329f0803142afc06c15a07b93937c1"
expected_st2_sha256="2bba8d58be24250bc262f75f835ce2d780369add275774f3f2135c623d23d29c"
expected_activity="46c71d31c0d6daee43adf568061b2b84a65ae8c0"
expected_guarded="743ceb796a41a3282e31382575bff0d0e3826d59"
net="$root/net"
pty_root="$net/pty"
fake_bin="$root/fake-bin"
send_log="$root/pty-send.log"
deliveries="$net/deliveries.log"
ding_log="$root/ding.log"
real_pty="$(command -v pty)"
ding_pid=""

cleanup() {
  if test -n "$ding_pid"; then
    kill "$ding_pid" 2>/dev/null || true
    wait "$ding_pid" 2>/dev/null || true
  fi
  PTY_ROOT="$pty_root" "$real_pty" kill control.target >/dev/null 2>&1 || true
  for _ in $(seq 1 80); do
    if PTY_ROOT="$pty_root" "$real_pty" rm control.target >/dev/null 2>&1; then
      break
    fi
    if ! PTY_ROOT="$pty_root" "$real_pty" list --json |
      jq -e '.[] | select(.name == "control.target")' >/dev/null; then
      break
    fi
    sleep 0.025
  done
}
trap cleanup EXIT

wait_for_text() {
  marker="$1"
  file="$2"
  for _ in $(seq 1 400); do
    if grep -Fq "$marker" "$file" 2>/dev/null; then
      return 0
    fi
    sleep 0.025
  done
  printf 'text %s did not reach %s\n' "$marker" "$file" >&2
  return 1
}

test "$(git -C "$package_root" rev-parse HEAD)" = "$expected_guarded"
git -C "$package_root" merge-base --is-ancestor "$expected_activity" "$expected_guarded"
test -z "$(git -C "$package_root" status --porcelain)"
test "$(readlink -f "$real_pty")" = "$(readlink -f "$package_root/bin/pty")"
case "$(st2 --version)" in
  "st2 0.1.0 — running from local source (${expected_st2:0:7}, "*")") ;;
  *) echo "unexpected st2 version" >&2; exit 1 ;;
esac
test "$(sha256sum "$(command -v st2)" | awk '{ print $1 }')" = "$expected_st2_sha256"

mkdir -p "$fake_bin"
cp "$root/pty-wrapper" "$fake_bin/pty"
chmod +x "$fake_bin/pty"
: >"$deliveries"
: >"$send_log"

PTY_ROOT="$pty_root" "$real_pty" run -d --id control.target --no-display-name \
  --env CATALOG="$net" -- perl "$net/fake-tui.pl"
for _ in $(seq 1 200); do
  if PTY_ROOT="$pty_root" "$real_pty" stats control.target --json >"$root/stats.json" 2>/dev/null; then
    break
  fi
  sleep 0.025
done
jq -e \
  '.activity.state == "unknown" and
   .activity.producerEpoch == null and
   .activity.sequence == 0 and
   .activity.generation == .generation' \
  "$root/stats.json" >/dev/null

st2 status control.target --set busy --catalog "$net" --host control --as control.target >/dev/null
CATALOG="$net" REAL_PTY="$real_pty" PTY_ROOT="$pty_root" PTY_SEND_LOG="$send_log" \
  PATH="$fake_bin:$PATH" \
  st2 ping control.target --identity control.target --catalog "$net" --host control --interval 50 \
  >"$ding_log" 2>&1 &
ding_pid="$!"
wait_for_text 'ready — found 0 existing unread message(s)' "$ding_log"

st2 message send control.target --catalog "$net" --host control --as control.sender \
  --subject aggressive-unknown-57 -m "durable aggressive control" >/dev/null
wait_for_text $'send\tsend\tcontrol.target' "$send_log"
wait_for_text aggressive-unknown-57 "$deliveries"
test "$(st2 message ls control.target --catalog "$net" --count)" -eq 1

kill "$ding_pid"
wait "$ding_pid" 2>/dev/null || true
ding_pid=""
cleanup
trap - EXIT
test "$(PTY_ROOT="$pty_root" "$real_pty" list --json | jq 'length')" -eq 0

echo "AGGRESSIVE-EXACT-HEADS-GREEN-57c1"
echo "AGGRESSIVE-UNCONFIGURED-GREEN-57c1"
echo "AGGRESSIVE-UNKNOWN-ACTIVITY-GREEN-57c1"
echo "AGGRESSIVE-PTY-SEND-GREEN-57c1"
echo "AGGRESSIVE-PANE-BYTES-GREEN-57c1"
echo "AGGRESSIVE-DURABLE-UNREAD-GREEN-57c1"
echo "AGGRESSIVE-CLEANUP-MODEL-FREE-GREEN-57c1"
