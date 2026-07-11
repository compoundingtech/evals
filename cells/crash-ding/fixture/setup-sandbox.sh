#!/usr/bin/env bash
# Materialize a per-HARNESS crash-ding sandbox: a short-pathed isolated dir with a git repo per member
# (cd-cos, cd-sup, cd-tg). Short paths on purpose — the unix-socket path limit (~104 bytes) forbids a deep
# <net>/pty/silber.<id>-<harness>.ding.sock. Fully synthetic + hermetic; nothing here touches the live convoy.
#   ./setup-sandbox.sh <codex|claude> [SANDBOX_BASE]
set -euo pipefail
H="${1:?usage: setup-sandbox.sh <codex|claude> [SANDBOX_BASE]}"
case "$H" in codex|claude) ;; *) echo "harness must be codex|claude" >&2; exit 1 ;; esac
BASE="${2:-${EVAL_SANDBOX:-/tmp}/cd}"
SB="$BASE-$H"                 # e.g. /tmp/cd-codex  (kept short for the socket-path limit)
rm -rf "$SB"; mkdir -p "$SB"
for id in cd-cos cd-sup cd-wk; do
  d="$SB/$id"; mkdir -p "$d"
  git -C "$d" init -q
  git -C "$d" config user.name  "$id"
  git -C "$d" config user.email "$id@eval.local"
  printf '# %s (crash-ding %s harness member)\n' "$id" "$H" > "$d/README.md"
  git -C "$d" add -A && git -C "$d" commit -q -m "seed $id"
done
echo "$SB"   # stdout = the resolved sandbox dir (spin.sh consumes it)
echo "SANDBOX READY: $SB   (harness=$H; members cd-cos/cd-sup/cd-wk; net will be $SB/net)" >&2
