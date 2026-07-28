#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
lock="$net/.st2.hl.lock"
fake="$root/fake-bin"
owner=""

cleanup() {
  if test -n "$owner"; then
    kill "$owner" 2>/dev/null || true
    wait "$owner" 2>/dev/null || true
  fi
  test ! -e "$lock" || unlink "$lock"
}
trap cleanup EXIT

mkdir -p "$fake"
cp "$root/pty-readable" "$fake/pty"
chmod +x "$fake/pty"

PATH="$fake:$PATH" st2 doctor --catalog "$net" --host hl >"$root/manual.out"
set +e
PATH="$fake:$PATH" st2 doctor --catalog "$net" --host hl --require-supervisor \
  >"$root/required.out" 2>"$root/required.err"
required_exit="$?"
set -e
test "$required_exit" -ne 0
grep -Fq 'required but no live host-lock' "$root/required.out"
echo "REQUIRE-SUPERVISOR-FAILS-CLOSED-a77e"

printf '%s\n' 2000000000 >"$lock"
set +e
PATH="$fake:$PATH" st2 doctor --catalog "$net" --host hl \
  >"$root/stale.out" 2>"$root/stale.err"
stale_exit="$?"
set -e
test "$stale_exit" -ne 0
grep -Fq 'stale host-lock from a dead supervisor' "$root/stale.out"
echo "STALE-LOCK-FAILS-CLOSED-a77e"

sleep 100000 &
owner="$!"
printf '%s\n' "$owner" >"$lock"
PATH="$fake:$PATH" st2 doctor --catalog "$net" --host hl --require-supervisor \
  >"$root/foreign.out"
grep -Fq 'supervisor (st2 up) running' "$root/foreign.out"
echo "FOREIGN-LIVE-OWNER-GREEN-a77e"

cp "$root/pty-hung" "$fake/pty"
chmod +x "$fake/pty"
started="$(date +%s)"
set +e
PATH="$fake:$PATH" st2 doctor --catalog "$net" --host hl \
  >"$root/hung.out" 2>"$root/hung.err"
hung_exit="$?"
set -e
elapsed=$(( $(date +%s) - started ))
test "$hung_exit" -ne 0
test "$elapsed" -le 4
grep -Fq 'task runtime readable' "$root/hung.out"
grep -Fq 'timed out after 2.0s' "$root/hung.out"
echo "UNREADABLE-PTY-BOUNDED-a77e"

kill "$owner"
wait "$owner" 2>/dev/null || true
owner=""
unlink "$lock"
test ! -e "$lock"
echo "HOST-LOCK-CLEANUP-GREEN-a77e"
