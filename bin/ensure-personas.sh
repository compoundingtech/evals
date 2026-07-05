#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ensure-personas.sh — clone the PUBLIC personas repo at a pinned SHA (read-only
# contract) into a local cache, and print its path on stdout. Cells compose their
# agents from these role files; pinning is what makes a run reproducible.
#
#   PERSONAS_DIR="$(bin/ensure-personas.sh)"   # clone-if-needed, checkout pin, echo dir
#
# Override the source/pin with PERSONAS_URL / PERSONAS_PIN. Needs network ONCE
# (the first clone); every run after is offline.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

PERSONAS_URL="${PERSONAS_URL:-https://github.com/myobie/personas}"
# The public contract, pinned. Bump deliberately; reproducibility = this SHA.
PERSONAS_PIN="${PERSONAS_PIN:-f12458a3a0139ab31bcad7c8b3a9f5750f873a97}"
DEST="${PERSONAS_DIR:-$ROOT/.personas}"

if [ ! -d "$DEST/.git" ]; then
  git clone -q "$PERSONAS_URL" "$DEST" >&2
fi
# Make sure the pin is present (a shallow default clone may not have it), then check it out.
git -C "$DEST" rev-parse --verify -q "$PERSONAS_PIN^{commit}" >/dev/null 2>&1 \
  || git -C "$DEST" fetch -q origin >&2 || true
git -C "$DEST" checkout -q "$PERSONAS_PIN" >&2

got="$(git -C "$DEST" rev-parse HEAD)"
if [ "$got" != "$PERSONAS_PIN" ]; then
  echo "ensure-personas: checkout is ${got:0:12}, expected ${PERSONAS_PIN:0:12}" >&2
  exit 1
fi
# The role files a cell may reference must exist at the pin.
for f in dev-practices.md known-harness-bugs.md manager.md specialist.md; do
  [ -r "$DEST/$f" ] || { echo "ensure-personas: missing $f at pin" >&2; exit 1; }
done
echo "$DEST"
