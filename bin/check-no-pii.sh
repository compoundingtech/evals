#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check-no-pii — a publish-time backstop. Before you share your own cells, scan
# the tree for machine-specific absolute paths (and any private tokens you name)
# that shouldn't leave your machine. Exit 1 with offenders if any hit; 0 = clean.
#
#   check-no-pii.sh [DIR]                         # scan DIR (default: repo root)
#   PII_TOKENS='alex|widgetco|acme-internal' check-no-pii.sh cells/my-cell
#
# By default it flags absolute home/volume paths (…/Users/<you>/…, /home/<you>/…,
# /Volumes/<disk>/…) — the usual way a machine path sneaks into a fixture. Add
# your own names/handles/private-repo tokens via PII_TOKENS (pipe-separated).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$HERE/.." && pwd)}"

# Things that almost never belong in a portable, shareable fixture:
#  - absolute machine paths (raw and the dash-encoded scratchpad form)
#  - session-id UUIDs
#  - <name>-claude style agent handles (a specific-harness identity) — but NOT a
#    `$var-claude` session-name construction or a `configure-claude-agent.sh` filename
MACHINE_PATHS='/Users/[^/[:space:]"]+|/home/[^/[:space:]"]+|/Volumes/[^/[:space:]"]+|/private/tmp|-Volumes-[A-Za-z0-9]|-Users-[A-Za-z0-9]'
SESSION_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
AGENT_HANDLE='(^|[^$A-Za-z0-9_/])[a-z][a-z0-9]{2,}-claude([^-A-Za-z0-9]|$)'
DEFAULT="${MACHINE_PATHS}|${SESSION_UUID}|${AGENT_HANDLE}"
FORBIDDEN="${PII_TOKENS:+${PII_TOKENS}|}${DEFAULT}"

mapfile -t HITS < <(
  grep -rInEi "$FORBIDDEN" "$ROOT" \
    --exclude-dir=.git --exclude-dir=.build --exclude-dir=.sandbox \
    --exclude-dir=.personas --exclude-dir=node_modules \
    --exclude='check-no-pii.sh' 2>/dev/null
)

if [ "${#HITS[@]}" -eq 0 ]; then
  echo "✓ check-no-pii CLEAN — no machine paths / listed tokens in $ROOT"
  exit 0
else
  echo "✗ check-no-pii FAILED — ${#HITS[@]} hit(s) in $ROOT:"
  printf '  %s\n' "${HITS[@]}"
  echo "  (portable fixtures use env vars — \$HOME, \${ST_ROOT}, \${EVAL_SANDBOX} — not absolute machine paths.)"
  exit 1
fi
