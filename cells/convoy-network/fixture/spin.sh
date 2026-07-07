#!/usr/bin/env bash
# Spin the convoy-network CAPSTONE (the reboot go/no-go): `convoy add` a cos + worker (ding, NO MCP), seed the
# task, and HOST them with `convoy up` (foreground supervisor + respawn, --json event stream). Stand up → host →
# message → threaded reply, all ding/no-MCP/no-app; a mid-run kill (kill-injector) the host must RESPAWN. AFTER setup.
#   ./spin.sh [SANDBOX]        # needs: CONVOY_BIN (a convoy with `up`), PERSONAS_DIR.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/convoy-network}"
CONVOY="${CONVOY_BIN:-convoy}"
NET="$SB/net"
[ -d "$NET" ] || "$HERE/setup-sandbox.sh" "$SB"
export ST_ROOT="$NET"                                # the isolated network — never the operator's live one

echo "== compose personas (cos + worker; ding, no MCP) =="
"$HERE/compose-persona.sh" cos "$SB" >/dev/null
"$HERE/compose-persona.sh" worker "$SB" >/dev/null

echo "== convoy add the worker (ding, auto — NO MCP) =="
# Re-runnable: clear any stale registration first (convoy add errors on an existing identity, and that state can
# survive a fresh `convoy init` — a real quirk the live run surfaced). Belt-and-suspenders; harmless on a clean net.
"$CONVOY" remove cap-wk  --network "$NET" --yes >/dev/null 2>&1 || true
"$CONVOY" remove cap-cos --network "$NET" --yes >/dev/null 2>&1 || true
"$CONVOY" add worker --identity cap-wk --network "$NET" --dir "$SB/worker" --persona "$SB/personas-local/cap-wk.md" --yes

echo "== convoy add the cos (ding, bypass, PERMANENT — the respawn target) =="
"$CONVOY" add cos --identity cap-cos --network "$NET" --dir "$SB/cos" --persona "$SB/personas-local/cap-cos.md" --yes

# Seed the kick AFTER convoy add cos: pre-creating cap-cos's inbox dir makes `convoy add cos` think the identity
# already exists (the live run surfaced this). ding delivers a kick that arrives after boot, so this is fine.
echo "== seed the requester's kick into cap-cos's inbox (record the filename for the threaded-reply check) =="
mkdir -p "$NET/cap-cos/inbox" "$NET/cap-cos/archive" "$NET/cap-req/inbox" "$NET/cap-req/archive"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
kickfn="${ms}-${sfx}.md"; sed -n '/^---$/,$p' "$HERE/kick.md" > "$NET/cap-cos/inbox/$kickfn"
printf '%s\n' "$kickfn" > "$SB/.kick-filename"; echo "   seeded $NET/cap-cos/inbox/$kickfn"

echo "== HOST with 'convoy up' (foreground supervisor + respawn; --json event stream captured) =="
: > "$SB/.convoy-up.log"
"$CONVOY" up "$NET" --json >> "$SB/.convoy-up.log" 2>&1 &
echo $! > "$SB/.convoy-up.pid"
echo "   convoy up hosting (pid $(cat "$SB/.convoy-up.pid")); events -> $SB/.convoy-up.log"

echo
echo "SPUN (convoy-network, isolated net $NET). convoy up HOSTS cap-cos (permanent) + cap-wk (ding, no MCP)."
echo "OBSERVE: cap-cos delegates to cap-wk -> cap-wk reads ANSWER.txt + replies on-thread -> cap-cos replies to"
echo "  cap-req on-thread. INJECT the mid-run kill: $HERE/kill-injector.sh \"$SB\"  (convoy up must RESPAWN cap-wk)."
echo "GRADE:    $HERE/grade.sh \"$SB\""
echo "TEARDOWN: kill \$(cat $SB/.convoy-up.pid) 2>/dev/null; $CONVOY remove cap-cos --network \"$NET\"; $CONVOY remove cap-wk --network \"$NET\""
