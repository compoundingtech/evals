#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (CODEX twin) — the DETERMINISTIC (box-free) core. Same shape as ../../restorability/fixture/probe.sh,
# but the hook under test is the CODEX SessionStart hook, whose mechanism DIFFERS: it emits a JSON payload on
# STDOUT ({"additionalContext": "...", "continue": true}) rather than the claude hook's stderr+exit-2. The injected
# now.md block uses the SAME marker on both hooks — <context source="st/context/now.md" agent="<id>">.
#
#   1. CODEX-HOOK-EMITS-BLOCK (smalltalk PR #86): run examples/codex/session-start.sh against the fixture now.md;
#      jq .additionalContext must contain the marker + token. Requires jq (the codex hook hard-deps it) — the gate
#      SKIPS-WITH-REASON if jq is absent. Negatives: missing/stale now.md (+ empty inbox) => no now.md block.
#   2. NO-RESUME + NO-QUEUE-CHANNEL: materialize the real codex pty.toml (what `convoy reload` respawns from) and
#      prove the stored command carries NO --resume/--session-id (a fresh cold boot).
#
# Nothing here needs a live model. Fully isolated + torn down; never touches the live convoy.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/rlx}"
[ -f "$SB/now.md.seed" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }
TOKEN="$(tr -d '\r\n' < "$SB/.token" 2>/dev/null)"
P="$SB/.probe"; rm -rf "$P"; mkdir -p "$P"
cp "$SB/.token" "$P/token.txt"

resolve_smalltalk() {
  if [ -n "${SMALLTALK_REPO:-}" ] && [ -d "$SMALLTALK_REPO" ]; then printf '%s\n' "$SMALLTALK_REPO"; return 0; fi
  local stbin; stbin="$(command -v st 2>/dev/null)" || return 1
  local real; real="$(readlink -f "$stbin" 2>/dev/null || realpath "$stbin" 2>/dev/null || printf '%s' "$stbin")"
  printf '%s\n' "$(cd "$(dirname "$real")/.." && pwd)"
}
SMREPO="$(resolve_smalltalk || true)"
HOOK="${SMREPO:+$SMREPO/examples/codex/session-start.sh}"
printf '%s\n' "${HOOK:-<unresolved>}" > "$P/hook-path.txt"

echo "== 1/2  CODEX-HOOK-EMITS-BLOCK — run the codex SessionStart hook against the fixture now.md (+ negatives) =="
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not on PATH (the codex hook hard-deps jq) — codex hook gate will skip-with-reason" >&2
  printf 'JQ-MISSING\n' > "$P/hook-fresh.json"
elif [ -n "$HOOK" ] && [ -f "$HOOK" ]; then
  # PATH must reach BOTH st (smalltalk bin) and jq.
  HPATH="${SMREPO:+$SMREPO/bin:}$PATH"
  R="$P/root/rlx-wk"; mkdir -p "$R/context" "$R/inbox" "$R/archive"
  # (a) FRESH now.md + empty inbox + bypass freshness => now.md-only payload on stdout.
  cp "$SB/now.md.seed" "$R/context/now.md"
  PATH="$HPATH" ST_ROOT="$P/root" ST_AGENT=rlx-wk ST_REHYDRATE_STALE_S=999999999 bash "$HOOK" >"$P/hook-fresh.json" 2>"$P/hook-fresh.err"
  printf '%s\n' "$?" > "$P/hook-fresh.exit"
  # (b) NEGATIVE — MISSING now.md + empty inbox => silent exit 0, no payload.
  rm -f "$R/context/now.md"
  PATH="$HPATH" ST_ROOT="$P/root" ST_AGENT=rlx-wk ST_REHYDRATE_STALE_S=999999999 bash "$HOOK" >"$P/hook-missing.json" 2>/dev/null
  # (c) NEGATIVE — STALE now.md (aged) + empty inbox => no now.md block.
  cp "$SB/now.md.seed" "$R/context/now.md"; touch -t 202001010000 "$R/context/now.md"
  PATH="$HPATH" ST_ROOT="$P/root" ST_AGENT=rlx-wk ST_REHYDRATE_STALE_S=86400 bash "$HOOK" >"$P/hook-stale.json" 2>/dev/null
  echo "   ran codex hook: $HOOK  (fresh / missing / stale captured to $P/)"
else
  echo "SKIP: codex session-start hook not found (SMALLTALK_REPO=$SMREPO) — codex hook gate will report unresolved" >&2
  printf 'HOOK-UNRESOLVED\n' > "$P/hook-fresh.json"
fi

echo "== 2/2  NO-RESUME + NO-QUEUE-CHANNEL — materialize the REAL codex pty.toml =="
PTYTOML=""
for cand in "$SB/net/rlx-wk/pty.toml" "$SB/rlx-wk/pty.toml"; do [ -f "$cand" ] && { PTYTOML="$cand"; break; }; done
if [ -z "$PTYTOML" ]; then
  if command -v convoy >/dev/null 2>&1; then
    PNET="$SB/pnet"; pd="$P/wk"; mkdir -p "$pd"; git -C "$pd" init -q 2>/dev/null || true
    printf '# probe codex worker rlx-wk\nYou are rlx-wk.\n' > "$P/persona.md"
    export ST_ROOT="$PNET"; export PTY_ROOT="$PNET/pty"
    stev_convoy_init "$PNET" >/dev/null 2>&1 || true
    convoy add worker --identity rlx-wk --network "$PNET" --dir "$pd" --persona "$P/persona.md" --harness codex >"$P/add.out" 2>&1 || true
    for cand in "$pd/pty.toml" "$PNET/rlx-wk/pty.toml"; do [ -f "$cand" ] && { PTYTOML="$cand"; break; }; done
    stev_convoy_teardown "$PNET" >/dev/null 2>&1 || true
  fi
fi
if [ -n "$PTYTOML" ] && [ -f "$PTYTOML" ]; then
  cp "$PTYTOML" "$P/pty.toml"
  grep -E '^command = ' "$PTYTOML" | head -1 > "$P/reload-cmd.txt" 2>/dev/null || true
  echo "   captured $PTYTOML -> $P/pty.toml (+ reload-cmd.txt)"
else
  echo "SKIP: could not materialize codex pty.toml (convoy absent?) — NO-RESUME gate will report unresolved" >&2
fi

echo "== probe artifacts written to $P/ =="; ls -1 "$P" 2>/dev/null | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
