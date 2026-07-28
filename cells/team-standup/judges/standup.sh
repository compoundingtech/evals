#!/usr/bin/env bash
# JUDGE: STANDUP — a seat that this cell does not declare was really stood up, and it really participated.
#
# Two halves, because either alone is forgeable. A bus identity beyond the declared seat and the requester
# proves a third VOICE (but `st2 message send --as anything` could fake that from the supervisor). A pty
# session beyond the declared seat, running a model harness, proves a real seated PROCESS (but a bare
# `sleep` session would satisfy that alone). Together they are a specialist that exists and speaks.
#
# PASS (exit 0): a non-declared identity sent bus mail AND a non-declared harness session exists.
set -uo pipefail
SM="${ST_ROOT:-${CATALOG:-$PWD}}"                            # flat native st2 bus root
SUP_ID="${SUP_ID:-ts.cos}"; REQ_ID="${REQ_ID:-requester}"

fail=0

# Senders seen anywhere on the bus, tolerating a leading team/host prefix on the declared ids.
senders="$(grep -rhsE '^from:[[:space:]]*[A-Za-z0-9]' "$SM" --include='*.md' 2>/dev/null |
  sed -E 's/^from:[[:space:]]*//; s/[[:space:]]+$//' | sort -u)"
third="$(printf '%s\n' "$senders" |
  grep -vE "^([a-z0-9][a-z0-9._-]*\.)?(${SUP_ID##*.}|${REQ_ID})\$" | grep -v '^$' || true)"
if [ -n "$third" ]; then
  echo "PASS: bus voice(s) beyond the declared seat: $(printf '%s' "$third" | tr '\n' ' ')"
else
  echo "FAIL: every bus message came from $SUP_ID or $REQ_ID — no specialist was stood up"
  echo "  senders seen: $(printf '%s' "$senders" | tr '\n' ' ')"
  fail=1
fi

# A live (or exited) session in the eval's hermetic pty registry that is NOT the declared seat and runs a
# model harness. PTY_ROOT is the eval's, inherited from the runner, so this can never read the operator's.
sessions="$(pty list 2>/dev/null || true)"
spawned="$(printf '%s\n' "$sessions" | grep -i 'claude' | grep -v "$SUP_ID" || true)"
if [ -n "$spawned" ]; then
  echo "PASS: a harness session beyond the declared seat exists in the eval's pty registry"
else
  echo "FAIL: no non-declared harness session — nothing was seated, only messaged"
  fail=1
fi

exit "$fail"
