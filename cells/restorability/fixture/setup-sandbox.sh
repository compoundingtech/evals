#!/usr/bin/env bash
# Materialize the restorability sandbox: a short-pathed isolated dir holding the worker agent's git repo. Short
# paths on purpose — the unix-socket path limit (~104 bytes) forbids a deep <net>/pty/silber.<id>.ding.sock.
# spin.sh does the live convoy work (init + add the worker + seed now.md + archive a poke + `convoy reload`
# no-resume + a --resume control). Fully synthetic + hermetic; nothing here touches the live convoy.
#   ./setup-sandbox.sh [SANDBOX_BASE]
set -euo pipefail
BASE="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
SB="$BASE"                    # kept short for the socket-path limit
rm -rf "$SB"; mkdir -p "$SB"

# The one worker whose cold-restart we test. Its own git repo (distinct author) so isolation attribution holds
# ACROSS the reload (the relaunch keeps the same identity => same git author).
d="$SB/rl-wk"; mkdir -p "$d"
git -C "$d" init -q
git -C "$d" config user.name  "rl-wk"
git -C "$d" config user.email "rl-wk@eval.local"
printf '# rl-wk (restorability worker — cold-restarted via convoy reload, no --resume)\n' > "$d/README.md"
# RECONSTRUCTED.log is where the cold-booted agent proves it reconstructed now.md's resume-task (echoes a token).
# Absent at seed so grade.sh can assert the cold agent CREATED it from durable state alone.
git -C "$d" add -A && git -C "$d" commit -q -m "seed rl-wk"

echo "$SB"   # stdout = the resolved sandbox dir (spin.sh consumes it)
echo "SANDBOX READY: $SB   (worker rl-wk; net will be $SB/net; spin.sh seeds now.md + reloads no-resume)" >&2
