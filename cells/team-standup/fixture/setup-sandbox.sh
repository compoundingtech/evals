#!/usr/bin/env bash
# Materialize the TEAM-STANDUP eval sandbox. Picks up where first-run leaves off: a CoS is already
# stood up (interviewed, team.md lists Jordan's repos). Now we test whether the CoS can stand up a
# WORKING TEAM — spin + brief a specialist for one repo, and have it take a real delegated task
# end-to-end. See TEAM-STANDUP-GATE.md.
#
#   ./setup-sandbox.sh [SANDBOX]
#
# Builds:
#   st-root/            a fresh, isolated bus root (never the live network)
#     cos/              the interviewed CoS (coordinate-only; owns NO repo) — status available
#   taskflow/           the repo the specialist (taskflow-dev) will own — a small GREEN task lib
#   cos/team.md         Jordan's roster (taskflow + taskflow-web) — the standup reads this
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
STR="$SB/st-root"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB" "$STR"

# ── the CoS (coordinate-only; its dir is NOT a git repo, so it cannot commit — structural isolation) ──
COS="$SB/cos"; mkdir -p "$COS"
mkdir -p "$STR/cos/inbox" "$STR/cos/archive"; printf 'available\n' > "$STR/cos/status"

# team.md — the interviewed roster (from the synthetic Jordan principal). The standup reads this to
# know which repos exist + their one-liner/priority, and records the specialist it stands up here.
cat > "$COS/team.md" <<'MD'
# team / roster

## projects
- **taskflow** — the SaaS backend (API + jobs) (owner: jordan)
- **taskflow-web** — the web client (owner: jordan)

## priorities
1. Ship the taskflow private beta
2. Keep CI green on main

## people
- Sam Ortiz — product designer, reviews UX

## agents
- (none stood up yet — the CoS stands these up lazily, on first work for a repo)
MD

# ── taskflow: the specialist's repo — small, GREEN, ready for a small delegated unit of work ──
W="$SB/taskflow"; mkdir -p "$W/src" "$W/test"

cat > "$W/src/tasks.js" <<'JS'
// taskflow — a tiny in-memory task store (the SaaS backend's core).
let seq = 0;
const tasks = [];

export function addTask(title) {
  if (typeof title !== "string" || title.trim() === "") throw new TypeError("title required");
  const t = { id: ++seq, title, done: false };
  tasks.push(t);
  return t;
}

export function listTasks() {
  return tasks.map((t) => ({ ...t }));
}
JS

cat > "$W/test/tasks.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { addTask, listTasks } from "../src/tasks.js";

test("addTask returns an open task with an id", () => {
  const t = addTask("write the changelog");
  assert.equal(t.title, "write the changelog");
  assert.equal(t.done, false);
  assert.ok(t.id > 0);
});

test("addTask rejects an empty title", () => {
  assert.throws(() => addTask("  "), TypeError);
});

test("listTasks returns a copy", () => {
  addTask("ship the beta");
  const a = listTasks();
  a[0].title = "mutated";
  assert.notEqual(listTasks()[0].title, "mutated");
});
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "taskflow",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "taskflow — a small task-tracking SaaS backend.",
  "main": "src/tasks.js",
  "scripts": { "test": "node --test" }
}
JSON

cat > "$W/README.md" <<'MD'
# taskflow

A small task-tracking SaaS backend. `addTask(title)` creates an open task; `listTasks()` returns them.

Run the tests with `npm test`.
MD

cat > "$W/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
PERSONA.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init taskflow (frozen base) =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "taskflow: initial task store"
git -C "$W" config user.name  "taskflow-dev"
git -C "$W" config user.email "taskflow-dev@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo "== sanity: taskflow suite is GREEN =="
( cd "$W" && node --test >/dev/null 2>&1 && echo "  suite: GREEN" || echo "  !! suite RED (unexpected)" )

echo
echo "SANDBOX READY: $SB   (taskflow base $BASE; specialist author taskflow-dev)"
echo "  st-root/   fresh bus root (cos online, available)"
echo "  cos/       interviewed CoS (coordinate-only, owns no repo); team.md = Jordan's roster"
echo "  taskflow/  the repo the CoS will stand up 'taskflow-dev' to own (GREEN suite)"
echo "next: gate-p4.sh (hermetic standup mechanics) then spin.sh (live delegate->execute->walk)."
