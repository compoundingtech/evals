#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the restorability-CODEX sandbox — the codex twin of ../../restorability. Short-pathed for the
# ~104-byte unix-socket limit. Fully synthetic + hermetic. Produces the SAME shape as the claude cell (worker repo
# + now.md.seed + .token), for a codex worker (rlx-wk).
#   ./setup-sandbox.sh [SANDBOX_BASE]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
BASE="${1:-${EVAL_SANDBOX:-/tmp}/rlx}"
SB="$BASE"
rm -rf "$SB"; mkdir -p "$SB"

if command -v uuidgen >/dev/null 2>&1; then
  NONCE="$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | cut -c1-8)"
else
  NONCE="$(printf '%08x' "$(( (RANDOM << 16 ^ RANDOM << 8 ^ RANDOM) & 0xffffffff ))")"
fi
TOKEN="RESTORE-CX-${NONCE}"
printf '%s\n' "$TOKEN" > "$SB/.token"

d="$SB/rlx-wk"; mkdir -p "$d"
git -C "$d" init -q
git -C "$d" config user.name  "rlx-wk"
git -C "$d" config user.email "rlx-wk@eval.local"
printf '# rlx-wk (restorability CODEX worker — cold-restarted via convoy reload, no --resume/--session-id)\n' > "$d/README.md"
git -C "$d" add -A && git -C "$d" commit -q -m "seed rlx-wk"

cat > "$SB/now.md.seed" <<SEED
# now.md — rlx-wk durable working state (restorability-codex run)

## MID-TASK (resume this exactly)
Your one open task: run this exact command in your repo, then stand by:

    echo $TOKEN > RECONSTRUCTED.log && git add RECONSTRUCTED.log && git commit -m "reconstruct: $TOKEN"

marker: $TOKEN
SEED

echo "$SB"
echo "SANDBOX READY: $SB   (codex worker rlx-wk; token $TOKEN; now.md.seed written; net will be $SB/net)" >&2
