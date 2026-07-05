#!/usr/bin/env bash
# Materialize the Test-writing eval sandbox. A small, CORRECT-but-UNTESTED `grades` module (letter grades,
# GPA points, a summary aggregate). The team's job: write a real test suite for it. The deliverable IS the
# tests. Discriminator: a MUTATION SCORE across a battery of ~12 planted mutants (boundary flips, threshold
# constants, aggregation ops, guards — see mutants.sh). A thorough suite (boundaries + throw-paths +
# aggregation asserted exactly) KILLS them all; a shallow "one happy path" suite or coverage theater (runs
# the code, asserts little) SURVIVES several. This is distinct from the incident cell's single-mutant
# regression check: here the deliverable is a whole suite, graded by kill-rate over many mutants. See
# tasks/test-writing.toml.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/test-writing
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/test-writing}"
source "$HERE/mutants.sh"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = coordinate-only, owns NO repo
W="$SB/worker"; mkdir -p "$W/src" "$W/test"

echo "== worker repo: grades module (correct, UNTESTED) =="
cat > "$W/src/grades.js" <<'JS'
// grades — turn numeric scores into letter grades, GPA points, and a summary.

export function letter(score) {
  if (typeof score !== "number" || Number.isNaN(score)) {
    throw new TypeError("score must be a number");
  }
  if (score < 0 || score > 100) {
    throw new RangeError("score must be between 0 and 100");
  }
  if (score >= 90) return "A";
  if (score >= 80) return "B";
  if (score >= 70) return "C";
  if (score >= 60) return "D";
  return "F";
}

export function gpaPoints(ltr) {
  const points = { A: 4, B: 3, C: 2, D: 1, F: 0 };
  if (!(ltr in points)) {
    throw new RangeError(`unknown letter grade: ${ltr}`);
  }
  return points[ltr];
}

export function summary(scores) {
  if (!Array.isArray(scores) || scores.length === 0) {
    throw new RangeError("scores must be a non-empty array");
  }
  const letters = scores.map(letter);
  const counts = { A: 0, B: 0, C: 0, D: 0, F: 0 };
  for (const l of letters) counts[l] += 1;
  const gpa = letters.map(gpaPoints).reduce((a, b) => a + b, 0) / letters.length;
  const average = scores.reduce((a, b) => a + b, 0) / scores.length;
  return { count: scores.length, average, gpa, counts };
}
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "grades",
  "version": "0.2.0",
  "private": true,
  "type": "module",
  "description": "Letter grades, GPA points, and score summaries.",
  "main": "src/grades.js",
  "scripts": { "test": "node --test" }
}
JSON

cat > "$W/README.md" <<'MD'
# grades

Turn numeric scores (0–100) into letter grades, GPA points, and a summary.

```js
import { letter, gpaPoints, summary } from "./src/grades.js";
letter(85);                 // "B"
gpaPoints("B");             // 3
summary([90, 82, 71]);      // { count: 3, average: 81, gpa: 3, counts: { A:1, B:1, C:1, D:0, F:0 } }
```

- `letter(score)` — "A"/"B"/"C"/"D"/"F" by the usual 90/80/70/60 cutoffs; throws `TypeError`
  (non-number) / `RangeError` (outside 0–100).
- `gpaPoints(letter)` — A=4 … F=0; throws `RangeError` on an unknown letter.
- `summary(scores)` — `{ count, average, gpa, counts }`; throws `RangeError` on an empty array.

> **No tests yet.** `npm test` currently runs nothing — this module needs a real test suite.
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

echo "== git init worker repo (frozen base) + distinct author =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "grades: module v0.2.0 (no tests yet)"
git -C "$W" config user.name  "tw-dev"
git -C "$W" config user.email "tw-dev@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo
echo "== VALIDATE invariants =="
# 1) the module is CORRECT for known inputs (the code under test is sound; the team writes tests, not fixes)
CORR=$(cd "$W" && node --input-type=module -e '
import { letter, gpaPoints, summary } from "./src/grades.js";
const eq=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
let ok = letter(90)==="A" && letter(89)==="B" && letter(60)==="D" && letter(59)==="F" && letter(0)==="F" && letter(100)==="A"
  && gpaPoints("A")===4 && gpaPoints("F")===0;
const s = summary([90,80,70,60,50]);
ok = ok && s.count===5 && s.average===70 && s.gpa===2 && eq(s.counts,{A:1,B:1,C:1,D:1,F:1});
let threw=0; for (const f of [()=>letter(-1),()=>letter(101),()=>letter(NaN),()=>gpaPoints("Z"),()=>summary([])]){ try{f()}catch{threw++} }
console.log(ok && threw===5 ? "MODULE-OK" : "MODULE-BAD");
')
echo "  module correctness: $CORR"
[ "$CORR" = "MODULE-OK" ] || { echo "  [!!] module isn't behaving as specified"; exit 1; }

# 2) there are no tests yet (npm test runs nothing meaningful)
NT=$(cd "$W" && node --test 2>&1 | grep -cE "^# tests [1-9]" || true)
echo "  starting tests present: $([ "$NT" = 0 ] && echo none || echo some)"

# 3) SOLVABLE + mutants all KILLABLE: drop a REFERENCE thorough suite on a scratch copy -> kills all 12
SC=$(mktemp -d); cp -R "$W/." "$SC/w"; rm -rf "$SC/w/.git"
cat > "$SC/w/test/grades.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { letter, gpaPoints, summary } from "../src/grades.js";

test("letter: boundaries", () => {
  assert.equal(letter(100), "A"); assert.equal(letter(90), "A"); assert.equal(letter(89), "B");
  assert.equal(letter(80), "B");  assert.equal(letter(79), "C"); assert.equal(letter(70), "C");
  assert.equal(letter(69), "D");  assert.equal(letter(60), "D"); assert.equal(letter(59), "F");
  assert.equal(letter(0), "F");
});
test("letter: throws", () => {
  assert.throws(() => letter(-1), RangeError); assert.throws(() => letter(101), RangeError);
  assert.throws(() => letter(NaN), TypeError); assert.throws(() => letter("x"), TypeError);
});
test("gpaPoints: each letter + unknown", () => {
  assert.equal(gpaPoints("A"), 4); assert.equal(gpaPoints("B"), 3); assert.equal(gpaPoints("C"), 2);
  assert.equal(gpaPoints("D"), 1); assert.equal(gpaPoints("F"), 0);
  assert.throws(() => gpaPoints("Z"), RangeError);
});
test("summary: aggregates + empty throws", () => {
  const s = summary([90, 80, 70, 60, 50]);
  assert.equal(s.count, 5); assert.equal(s.average, 70); assert.equal(s.gpa, 2);
  assert.deepEqual(s.counts, { A: 1, B: 1, C: 1, D: 1, F: 1 });
  assert.throws(() => summary([]), RangeError);
});
JS
( cd "$SC/w" && node --test >/dev/null 2>&1 ) && echo "  reference suite: GREEN on original" || { echo "  [!!] reference suite RED on original"; rm -rf "$SC"; exit 1; }
echo "  reference-suite mutation run:"
MUT_OUT="$(run_mutation_score "$SC/w")"
printf '%s\n' "$MUT_OUT" | sed 's/^/    /'
rm -rf "$SC"
rk=$(printf '%s\n' "$MUT_OUT" | sed -n 's/.*MUTATION SCORE: \([0-9][0-9]*\)\/\([0-9][0-9]*\).*/\1/p')
rt=$(printf '%s\n' "$MUT_OUT" | sed -n 's/.*MUTATION SCORE: \([0-9][0-9]*\)\/\([0-9][0-9]*\).*/\2/p')
if [ "${rk:-0}" = "${rt:-0}" ] && [ "${rt:-0}" -gt 0 ]; then echo "  [ok] SOLVABLE: a thorough suite kills all $rt mutants"; else echo "  [!!] reference suite only killed ${rk:-0}/${rt:-0} — mutants not all killable (fix fixture)"; exit 1; fi

echo
echo "SANDBOX READY: $SB   (worker base $BASE; author tw-dev)"
echo "  worker/  grades (owned by tw-dev; CORRECT but UNTESTED; needs a real suite)"
echo "  sup/     coordinate-only (tw-sup cwd; owns no repo)"
echo "next: compose personas + wire agents (sup=bypass, dev=auto), seed the test-writing request, spin; grade.sh scores mutation kill-rate."
