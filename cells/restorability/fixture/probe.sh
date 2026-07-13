#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh — the DETERMINISTIC (box-free) core of restorability. Captures the ground-truth artifacts grade.sh
# asserts on, WITHOUT needing a live model to reason:
#
#   1. HOOK-EMITS-BLOCK (correction #1 STRONGER): run the claude SessionStart hook against the fixture now.md and
#      capture what it injects. Plus the two negatives — MISSING now.md and STALE now.md — that prove the gap the
#      empty-now.md agents (evals/planecast) hit.
#   2. NO-RESUME + NO-QUEUE-CHANNEL (mechanism corollary): materialize the REAL pty.toml (what `convoy reload`
#      respawns from) and capture the stored command — proving it carries NO --resume/--session-id and boots a
#      fresh session (no channel for a stuck queue to carry).
#
# Nothing here depends on a working Anthropic API — the hook is a shell script; pty.toml is written by `convoy add`
# regardless of whether the claude session then boots. Fully isolated + torn down; never touches the live convoy.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
[ -f "$SB/now.md.seed" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }
TOKEN="$(tr -d '\r\n' < "$SB/.token" 2>/dev/null)"
P="$SB/.probe"; rm -rf "$P"; mkdir -p "$P"
cp "$SB/.token" "$P/token.txt"

# ── Resolve the claude SessionStart hook portably (no baked machine paths) ────────────────────────────────────
# The hook ships in the smalltalk repo: <smalltalk>/examples/claude-code/hooks/session-start.sh. Discover the repo
# from the `st` binary's real path (readlink) → repo root = dirname(dirname). Override with SMALLTALK_REPO.
resolve_smalltalk() {
  if [ -n "${SMALLTALK_REPO:-}" ] && [ -d "$SMALLTALK_REPO" ]; then printf '%s\n' "$SMALLTALK_REPO"; return 0; fi
  local stbin; stbin="$(command -v st 2>/dev/null)" || return 1
  local real; real="$(readlink -f "$stbin" 2>/dev/null || realpath "$stbin" 2>/dev/null || printf '%s' "$stbin")"
  printf '%s\n' "$(cd "$(dirname "$real")/.." && pwd)"
}
SMREPO="$(resolve_smalltalk || true)"
HOOK="${SMREPO:+$SMREPO/examples/claude-code/hooks/session-start.sh}"
printf '%s\n' "${HOOK:-<unresolved>}" > "$P/hook-path.txt"

echo "== 1/3  HOOK-EMITS-BLOCK — run the claude SessionStart hook against the fixture now.md (+ negatives) =="
if [ -n "$HOOK" ] && [ -f "$HOOK" ]; then
  R="$P/root/rl-wk/context"; mkdir -p "$R"
  # (a) FRESH now.md + bypass the freshness gate deterministically (ST_REHYDRATE_STALE_S=999999999).
  cp "$SB/now.md.seed" "$R/now.md"
  ST_ROOT="$P/root" ST_AGENT=rl-wk ST_REHYDRATE_STALE_S=999999999 bash "$HOOK" >"$P/hook-fresh.out" 2>"$P/hook-fresh.txt"
  printf '%s\n' "$?" > "$P/hook-fresh.exit"
  # (b) NEGATIVE — MISSING now.md → context lost (no block).
  rm -f "$R/now.md"
  ST_ROOT="$P/root" ST_AGENT=rl-wk ST_REHYDRATE_STALE_S=999999999 bash "$HOOK" >/dev/null 2>"$P/hook-missing.txt"
  # (c) NEGATIVE — STALE now.md (aged well past the 24h threshold) → not injected (stale is worse than none).
  cp "$SB/now.md.seed" "$R/now.md"; touch -t 202001010000 "$R/now.md"
  ST_ROOT="$P/root" ST_AGENT=rl-wk ST_REHYDRATE_STALE_S=86400 bash "$HOOK" >/dev/null 2>"$P/hook-stale.txt"
  echo "   ran hook: $HOOK  (fresh / missing / stale captured to $P/)"
else
  echo "SKIP: claude session-start hook not found (SMALLTALK_REPO=$SMREPO) — HOOK gates will report unresolved" >&2
  printf 'HOOK-UNRESOLVED\n' > "$P/hook-fresh.txt"
fi

echo "== 2/3  NO-RESUME + NO-QUEUE-CHANNEL — materialize the REAL pty.toml (what convoy reload respawns from) =="
# Prefer a pty.toml already materialized by a live spin.sh (avoids a second convoy add). Else materialize one in an
# isolated, immediately-torn-down net. pty.toml is written by `convoy add` even if the claude session can't boot.
PTYTOML=""
for cand in "$SB/net/rl-wk/pty.toml" "$SB/rl-wk/pty.toml"; do [ -f "$cand" ] && { PTYTOML="$cand"; break; }; done
if [ -z "$PTYTOML" ]; then
  if command -v convoy >/dev/null 2>&1; then
    # Materialize into a THROWAWAY git repo (keep the real worker repo pristine — pty.toml is derived from the
    # identity/role, not the dir contents, so any repo works).
    PNET="$SB/pnet"; pd="$P/wk"; mkdir -p "$pd"; git -C "$pd" init -q 2>/dev/null || true
    printf '# probe worker rl-wk\nYou are rl-wk.\n' > "$P/persona.md"
    export ST_ROOT="$PNET"; export PTY_ROOT="$PNET/pty"     # isolate: session lands in the probe net, never global
    stev_convoy_init "$PNET" >/dev/null 2>&1 || true
    convoy add worker --identity rl-wk --network "$PNET" --dir "$pd" --persona "$P/persona.md" >"$P/add.out" 2>&1 || true
    for cand in "$pd/pty.toml" "$PNET/rl-wk/pty.toml"; do [ -f "$cand" ] && { PTYTOML="$cand"; break; }; done
    stev_convoy_teardown "$PNET" >/dev/null 2>&1 || true
  fi
fi
if [ -n "$PTYTOML" ] && [ -f "$PTYTOML" ]; then
  cp "$PTYTOML" "$P/pty.toml"
  # The stored claude command line — this is the exact string `convoy reload` re-execs.
  grep -E '^command = ' "$PTYTOML" | head -1 > "$P/reload-cmd.txt" 2>/dev/null || true
  echo "   captured $PTYTOML -> $P/pty.toml (+ reload-cmd.txt)"
else
  echo "SKIP: could not materialize pty.toml (convoy absent?) — NO-RESUME gate will report unresolved" >&2
fi

echo "== 3/3  probe artifacts written to $P/ =="
ls -1 "$P" 2>/dev/null | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
