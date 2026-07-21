#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# TEMPLATE — copy to cells/<name>/fixture/setup-sandbox.sh and adapt.
# Materialize the <name> eval sandbox: a small SYNTHETIC world, frozen at a base commit, no real
# repos/identities. Deterministic + reviewable. Personas + wiring + the hermetic kick happen AFTER
# this (in spin.sh). The visible suite (if any) must be green here.
#
#   ./setup-sandbox.sh [SANDBOX]        # defaults to ${EVAL_SANDBOX:-./.sandbox}/<name>
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SB="${1:-${EVAL_SANDBOX:-./.sandbox}/TODO_name}"

echo "== clean =="
rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = coordinate-only seat's cwd (owns NO product repo)
W="$SB/worker"; mkdir -p "$W"

echo "== worker repo: the synthetic world (TODO: make the task a REAL change, not a no-op) =="
# TODO: write the seed files the team wakes into. Keep it TINY and generic — no real code/identities.
cat > "$W/README.md" <<'MD'
# TODO(project)

TODO(seed content — the starting state the task will change).
MD

# eval-agent infra must never be committed into the product repo (isolation attribution stays clean)
cat > "$W/.gitignore" <<'GI'
node_modules/
.DS_Store
AGENTS.md
CLAUDE.md
PERSONA.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init worker repo (frozen base) + distinct, PINNED author =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "TODO(project): initial seed"
# Pin the repo's author to the OWNING agent so the isolation gate ("only the owner committed") is
# unambiguous on ANY box — otherwise the worker's commit falls back to the operator's GLOBAL git
# identity (the human running the eval) and the attribution gate breaks. (license-mit / ghost-bug do this.)
git -C "$W" config user.name  "${WORKER_ID:-TODO-worker}"
git -C "$W" config user.email "${WORKER_ID:-TODO-worker}@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo
echo "SANDBOX READY: $SB"
echo "  worker/  (owned by ${WORKER_ID:-TODO-worker}; base $BASE)"
echo "  sup/     (coordinate-only seat cwd; no product repo)"
echo "next: spin.sh — compose personas, convoy add each seat, seed the kick into the supervisor's inbox."
