#!/usr/bin/env bash
# Materialize the Poisoned-PR (code review) eval sandbox. A `configstore` repo with a GREEN baseline
# on `main` and an incoming PR branch `feat/file-config` that adds file-based config loading — and
# carries THREE planted defects that all PASS CI:
#   1. SECURITY (the headline): path traversal in loadConfig() — path.join(CONFIG_DIR, name) with an
#      un-sanitized name -> loadConfig("../../../../etc/passwd") escapes the config dir.
#   2. CORRECTNESS: mergeConfig() aliases + mutates its `base` argument (should return a fresh object).
#   3. TEST QUALITY: the only new test is tautological (asserts truthy, not the merge result); there is
#      NO test for loadConfig at all -> the traversal is completely uncovered.
# The suite is GREEN, so CI is happy. The review must catch what CI can't — and REQUEST CHANGES, not
# rubber-stamp. Discriminator: catch the security hole (+ the others), signal vs noise. See tasks/poisoned-pr.toml.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/poisoned-pr
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/poisoned-pr}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"          # sup/ = coordinate-only
R="$SB/rev"; mkdir -p "$R/src" "$R/test" "$R/config"          # rev/ = the reviewer's checkout

echo "== baseline (main): configstore =="
cat > "$R/src/store.js" <<'JS'
// In-memory config store.
const store = new Map();
export function set(key, value) { store.set(key, value); }
export function get(key) { return store.get(key); }
export function clear() { store.clear(); }
JS
cat > "$R/test/store.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { set, get, clear } from "../src/store.js";
test("set then get", () => { clear(); set("a", 1); assert.equal(get("a"), 1); });
test("missing key is undefined", () => { clear(); assert.equal(get("x"), undefined); });
JS
cat > "$R/config/app.json" <<'JSON'
{ "theme": "dark", "retries": 3 }
JSON
cat > "$R/package.json" <<'JSON'
{
  "name": "configstore",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "A tiny config store.",
  "main": "src/store.js",
  "scripts": { "test": "node --test" }
}
JSON
cat > "$R/README.md" <<'MD'
# configstore

A tiny config store: `set(key, value)`, `get(key)`, `clear()`. Run `npm test`.
MD
cat > "$R/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
REVIEW.md
GI

git -C "$R" init -q -b main
git -C "$R" add -A
git -C "$R" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "configstore: initial store (get/set/clear)"
BASE="$(git -C "$R" rev-parse --short HEAD)"

echo "== the incoming PR: feat/file-config (3 planted defects, all pass CI) =="
git -C "$R" checkout -q -b feat/file-config
cat > "$R/src/loader.js" <<'JS'
import fs from "node:fs";
import path from "node:path";
import { set } from "./store.js";

const CONFIG_DIR = path.join(process.cwd(), "config");

// Load a named JSON config file from the config dir and merge its keys into the store.
export function loadConfig(name) {
  const file = path.join(CONFIG_DIR, name);
  const data = JSON.parse(fs.readFileSync(file, "utf8"));
  for (const [k, v] of Object.entries(data)) set(k, v);
  return data;
}

// Merge override values over a base config object; overrides win.
export function mergeConfig(base, overrides) {
  const result = base;
  for (const k of Object.keys(overrides)) result[k] = overrides[k];
  return result;
}
JS
cat > "$R/test/loader.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { loadConfig, mergeConfig } from "../src/loader.js";

test("loadConfig loads app.json", () => {
  const cfg = loadConfig("app.json");
  assert.equal(cfg.theme, "dark");
});

test("mergeConfig combines objects", () => {
  const r = mergeConfig({ a: 1 }, { b: 2 });
  assert.ok(r);
});
JS
# PR bumps the README to advertise the feature
cat >> "$R/README.md" <<'MD'

## File config (PR: feat/file-config)
`loadConfig(name)` reads `config/<name>` and merges it into the store.
`mergeConfig(base, overrides)` merges two config objects.
MD
git -C "$R" add -A
git -C "$R" -c user.name="contributor" -c user.email="contributor@example.com" commit -q -m "feat: load config from files + mergeConfig helper"
PR="$(git -C "$R" rev-parse --short HEAD)"
git -C "$R" checkout -q feat/file-config   # leave the PR branch checked out for the reviewer

echo "== sanity: PR suite is GREEN (CI happy) but the defects are real =="
( cd "$R" && node --test >/dev/null 2>&1 && echo "  PR suite: GREEN (4 tests pass — CI would approve)" || echo "  !! suite RED (unexpected)" )
TRAV=$(cd "$R" && node --input-type=module -e '
import { loadConfig } from "./src/loader.js";
try { loadConfig("../package.json"); console.log("TRAVERSAL WORKS (escaped config/ — read ../package.json)"); }
catch (e) { console.log("traversal blocked:", e.code); }
' 2>&1)
echo "  security: $TRAV"

echo
echo "SANDBOX READY: $SB   (base $BASE; PR $PR on feat/file-config)"
echo "  rev/   configstore, feat/file-config checked out (reviewer diffs main..feat/file-config)"
echo "  sup/   coordinate-only"
echo "  planted: [1] loadConfig path traversal (security)  [2] mergeConfig mutates base (correctness)  [3] tautological mergeConfig test + no loadConfig-security test"
echo "next: compose personas + wire agents (sup=bypass, rev=auto), seed the review kick, spin."
