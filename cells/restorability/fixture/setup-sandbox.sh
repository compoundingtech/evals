#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the restorability sandbox (short-pathed for the ~104-byte unix-socket limit — a deep
# <net>/pty/silber.<id>.ding.sock must fit). Fully synthetic + hermetic; nothing here touches the live convoy.
#
# Produces:
#   $SB/rl-wk/                  the ONE worker whose cold-restart we test — its own git repo (distinct author so
#                               isolation attribution holds ACROSS the reload; RECONSTRUCTED.log ABSENT at seed so
#                               grade.sh can assert the cold agent CREATED it from durable state alone).
#   $SB/now.md.seed             the canonical now.md CONTENT (one source of truth): a durable resume-task that tells
#                               the cold-booted agent to echo this run's RECONSTRUCT token into RECONSTRUCTED.log.
#   $SB/.token                  this run's unique RECONSTRUCT token (grade.sh asserts the agent echoed THIS token,
#                               not a stale leftover — a fresh nonce per run).
#
# spin.sh does the live convoy work (init the isolated net + seed now.md into it + convoy add + convoy reload
# no-resume + the --resume discriminator control). probe.sh runs the box-free deterministic gates against the
# artifacts here.
#   ./setup-sandbox.sh [SANDBOX_BASE]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
BASE="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
SB="$BASE"                    # kept short for the socket-path limit
rm -rf "$SB"; mkdir -p "$SB"

# A fresh per-run RECONSTRUCT token (nonce). uuidgen when available; else a shell PRNG. The marker prefix stays
# stable (greppable) but the nonce differs each run so a leftover RECONSTRUCTED.log can never fake a PASS.
if command -v uuidgen >/dev/null 2>&1; then
  NONCE="$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | cut -c1-8)"
else
  NONCE="$(printf '%08x' "$(( (RANDOM << 16 ^ RANDOM << 8 ^ RANDOM) & 0xffffffff ))")"
fi
TOKEN="RESTORE-${NONCE}"
printf '%s\n' "$TOKEN" > "$SB/.token"

# The worker repo. Distinct author so the reload preserves attribution (same identity => same git author).
d="$SB/rl-wk"; mkdir -p "$d"
git -C "$d" init -q
git -C "$d" config user.name  "rl-wk"
git -C "$d" config user.email "rl-wk@eval.local"
printf '# rl-wk (restorability worker — cold-restarted via convoy reload, no --resume/--session-id)\n' > "$d/README.md"
git -C "$d" add -A && git -C "$d" commit -q -m "seed rl-wk"

# The canonical now.md content (the durable resume-task). The cold-booted agent, handed this via the SessionStart
# hook, must RECONSTRUCT the task and act on it — write the token to RECONSTRUCTED.log in its own repo. The
# instruction is self-contained (no coaching about restarts/resume — the whole point is that the substrate alone
# carries the agent back).
cat > "$SB/now.md.seed" <<SEED
# now.md — rl-wk durable working state (restorability run)

## MID-TASK (resume this exactly)
Your one open task: run this exact command in your repo, then stand by:

    echo $TOKEN > RECONSTRUCTED.log && git add RECONSTRUCTED.log && git commit -m "reconstruct: $TOKEN"

marker: $TOKEN
SEED

echo "$SB"   # stdout = the resolved sandbox dir (spin.sh / probe.sh consume it)
echo "SANDBOX READY: $SB   (worker rl-wk; token $TOKEN; now.md.seed written; net will be $SB/net)" >&2
