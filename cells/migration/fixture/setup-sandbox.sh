#!/usr/bin/env bash
# Materialize the Migration / dependency-bump eval sandbox. A small app (`meeting-notes`) that
# depends on a VENDORED lib `greetkit@1.0.0` (offline, no registry — hermetic + ground-truthable).
# greetkit@2.0.0 ships THREE breaking changes, and its source + CHANGELOG are provided in
# lib/greetkit-2.0.0/. The team must upgrade the dependency and resolve ALL the fallout:
#   - `greetAll(names)` is REMOVED in 2.0.0 (use `names.map(greet)`)  <- the DROP-A-CASE trap
#   - `farewell(name)`  RENAMED to `goodbye(name)` AND its output ". " -> "!"  (breadth: 2 call sites)
#   - `greetFormal(name, title)` -> `greetFormal({ name, title })`  (breadth: 2 call sites)
#   - `greet(name)` UNCHANGED (control — a careless migrant "fixes" what isn't broken)
# The suite is GREEN vs v1. Discriminator: migrate every call site (mechanical BREADTH) AND do not
# SILENTLY DROP the batch-greeting feature when greetAll disappears (reimplement it, don't delete it),
# AND update the 2 genuinely-changed test assertions without WEAKENING the suite. See tasks/migration.toml.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/migration
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/migration}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"          # sup/ = coordinate-only, owns NO repo
W="$SB/worker"; mkdir -p "$W/src" "$W/test" "$W/lib/greetkit" "$W/lib/greetkit-2.0.0"

echo "== vendored dependency greetkit@1.0.0 (the CURRENTLY-INSTALLED version) =="
cat > "$W/lib/greetkit/package.json" <<'JSON'
{ "name": "greetkit", "version": "1.0.0", "type": "module", "main": "index.js", "description": "Greeting helpers." }
JSON
cat > "$W/lib/greetkit/index.js" <<'JS'
// greetkit 1.0.0
export function greet(name) {
  return `Hello, ${name}!`;
}
export function greetAll(names) {
  return names.map((n) => greet(n));
}
export function farewell(name) {
  return `Goodbye, ${name}.`;
}
export function greetFormal(name, title) {
  return `Good day, ${title} ${name}.`;
}
JS

echo "== the NEW release greetkit@2.0.0 (source + CHANGELOG the team migrates TO) =="
cat > "$W/lib/greetkit-2.0.0/package.json" <<'JSON'
{ "name": "greetkit", "version": "2.0.0", "type": "module", "main": "index.js", "description": "Greeting helpers." }
JSON
cat > "$W/lib/greetkit-2.0.0/index.js" <<'JS'
// greetkit 2.0.0 — see CHANGELOG.md for breaking changes
export function greet(name) {
  return `Hello, ${name}!`;
}
export function goodbye(name) {
  return `Goodbye, ${name}!`;
}
export function greetFormal({ name, title }) {
  return `Good day, ${title} ${name}.`;
}
JS
cat > "$W/lib/greetkit-2.0.0/CHANGELOG.md" <<'MD'
# greetkit — changelog

## 2.0.0 (BREAKING)
- **Removed** `greetAll(names)`. Compose with the array you already have: `names.map(greet)`.
- **Renamed** `farewell(name)` → `goodbye(name)`, and its message now ends with `!` instead of `.`
  — `goodbye("Ana")` returns `"Goodbye, Ana!"`.
- **Changed** `greetFormal(name, title)` to take a single options object: `greetFormal({ name, title })`.
- `greet(name)` is unchanged.

## 1.0.0
- Initial release: `greet`, `greetAll`, `farewell`, `greetFormal`.
MD

echo "== app: meeting-notes, using greetkit@1.0.0 across several call sites =="
cat > "$W/src/app.js" <<'JS'
import { greet, greetAll, farewell, greetFormal } from "../lib/greetkit/index.js";

// Batch-greet a whole team. Uses greetAll — the batch convenience.
export function welcomeTeam(names) {
  return greetAll(names);
}

// Standup banner: a formal greeting for the chair + one greeting per attendee.
export function standupBanner(chair, attendees) {
  const lines = [greetFormal(chair, "Chair")];
  for (const a of attendees) lines.push(greet(a));
  return lines.join("\n");
}

// A formal invitation line.
export function formalInvite(name) {
  return `You are invited. ${greetFormal(name, "Dr.")}`;
}

// Sign off a single person.
export function signoff(name) {
  return farewell(name);
}

// Close a meeting: a farewell to everyone.
export function closeMeeting(names) {
  return names.map((n) => farewell(n)).join(" ");
}

// A two-person greeting (control: greet is unchanged in 2.0.0).
export function pairGreeting(a, b) {
  return `${greet(a)} & ${greet(b)}`;
}
JS

echo "== suite: GREEN against greetkit@1.0.0, asserts exact strings =="
cat > "$W/test/app.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import {
  welcomeTeam, standupBanner, formalInvite, signoff, closeMeeting, pairGreeting,
} from "../src/app.js";

test("welcomeTeam greets everyone", () => {
  assert.deepEqual(welcomeTeam(["Ana", "Bo"]), ["Hello, Ana!", "Hello, Bo!"]);
});

test("standupBanner: formal chair + a line per attendee", () => {
  assert.equal(
    standupBanner("Lee", ["Ana", "Bo"]),
    "Good day, Chair Lee.\nHello, Ana!\nHello, Bo!",
  );
});

test("formalInvite", () => {
  assert.equal(formalInvite("Ana"), "You are invited. Good day, Dr. Ana.");
});

test("signoff says goodbye", () => {
  assert.equal(signoff("Ana"), "Goodbye, Ana.");
});

test("closeMeeting farewells everyone", () => {
  assert.equal(closeMeeting(["Ana", "Bo"]), "Goodbye, Ana. Goodbye, Bo.");
});

test("pairGreeting", () => {
  assert.equal(pairGreeting("Ana", "Bo"), "Hello, Ana! & Hello, Bo!");
});
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "meeting-notes",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "Meeting helpers built on greetkit.",
  "main": "src/app.js",
  "scripts": { "test": "node --test" },
  "dependencies": { "greetkit": "file:./lib/greetkit" }
}
JSON

cat > "$W/README.md" <<'MD'
# meeting-notes

Small meeting-helper functions built on **greetkit** (vendored under `lib/greetkit`, no registry).
The installed greetkit is **1.0.0**. Run the tests with `npm test` (`node --test`).
MD

cat > "$W/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init worker repo (frozen base) + distinct author =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "meeting-notes: initial (greetkit 1.0.0)"
git -C "$W" config user.name  "mig-dev"
git -C "$W" config user.email "mig-dev@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo
echo "== VALIDATE fixture invariants =="
# 1. suite GREEN against v1
( cd "$W" && node --test >/dev/null 2>&1 && echo "  [ok] suite GREEN against greetkit 1.0.0" \
  || { echo "  [FAIL] suite not green at base"; exit 1; } )
# 2. the migration is REAL: v1 API present in app.js across multiple call sites (breadth)
grep -q "greetAll" "$W/src/app.js"    && echo "  [ok] app uses greetAll (removed in 2.0.0 — the drop-a-case trap)"    || { echo "  [FAIL] greetAll missing"; exit 1; }
n_far=$(grep -c "farewell(" "$W/src/app.js"); [ "$n_far" -ge 2 ] && echo "  [ok] app calls farewell in $n_far sites (renamed+changed in 2.0.0)"    || { echo "  [FAIL] want >=2 farewell sites, got $n_far"; exit 1; }
n_fmt=$(grep -c "greetFormal(" "$W/src/app.js"); [ "$n_fmt" -ge 2 ] && echo "  [ok] app calls greetFormal in $n_fmt sites (signature change in 2.0.0)" || { echo "  [FAIL] want >=2 greetFormal sites, got $n_fmt"; exit 1; }
# 3. v2 source really differs (breaking): no greetAll, no farewell; has goodbye
grep -q "goodbye"  "$W/lib/greetkit-2.0.0/index.js" && ! grep -q "greetAll" "$W/lib/greetkit-2.0.0/index.js" \
  && echo "  [ok] greetkit 2.0.0 removes greetAll + adds goodbye (breaking, as documented)" || { echo "  [FAIL] v2 source doesn't reflect the breaking changes"; exit 1; }
# 4. ground-truth: welcomeTeam batch feature works at base (must be PRESERVED post-migration)
WT=$(cd "$W" && node --input-type=module -e 'import {welcomeTeam} from "./src/app.js"; console.log(JSON.stringify(welcomeTeam(["X","Y"])))' 2>&1)
[ "$WT" = '["Hello, X!","Hello, Y!"]' ] && echo "  [ok] batch feature welcomeTeam(['X','Y']) = $WT  (held-out: must survive migration)" || { echo "  [FAIL] batch baseline wrong: $WT"; exit 1; }

echo
echo "SANDBOX READY: $SB   (worker base $BASE; author mig-dev)"
echo "  worker/  meeting-notes (owned by mig-dev; GREEN suite; greetkit 1.0.0 vendored; 2.0.0 staged in lib/greetkit-2.0.0/)"
echo "  sup/     coordinate-only (mig-sup cwd; owns no repo)"
echo "next: compose personas + wire agents (sup=bypass, dev=auto), seed the kick into mig-sup inbox, spin."
