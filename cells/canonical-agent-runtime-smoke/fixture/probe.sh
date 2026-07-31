#!/usr/bin/env bash
set -euo pipefail

test "$CATALOG" = "$ST_ROOT"
test "$PTY_ROOT" = "$CATALOG/pty"
test "$ST_AGENT" = "evalhost.probe"
mkdir -p "$CATALOG/probe"
printf '%s\n' "$$" >"$CATALOG/probe/work.pid"
echo "canonical probe ready"
touch "$CATALOG/probe/roots-ok"

for _ in $(seq 1 200); do
  if test "$(st2 message ls "$ST_AGENT" --catalog "$CATALOG" --from requester --count)" -gt 0; then
    touch "$CATALOG/probe/kickoff-seen"
    st2 message send requester --catalog "$CATALOG" --as "$ST_AGENT" <<'MSG'
Canonical kickoff received.
MSG
    exec sleep 60
  fi
  sleep 0.05
done

echo "canonical kickoff did not arrive" >&2
exit 1
