#!/usr/bin/env bash
# Materialize the Incident-response ("Prod is down") eval sandbox. A small `pulse` metrics service
# whose GET /stats endpoint is throwing 500s in "prod". Root cause: an OFF-BY-ONE in percentile() —
# it indexes the ascending-sorted samples with the 1-based nearest RANK as a 0-based index
# (`sorted[ceil(p*N)]`), so it (a) reads OUT OF BOUNDS -> undefined -> `.toFixed` TypeError -> 500 for
# small-sample metrics, and (b) returns silently-WRONG (off-by-one-high) percentiles otherwise.
# The existing suite is GREEN: it only exercises a healthy 24-sample metric and asserts percentiles
# loosely, so the latent bug slipped through CI — a classic incident.
#
# DISCRIMINATOR (incident-response, suite #7): triage -> hotfix (stop the bleed) -> ROOT-CAUSE fix +
# regression test. The tempting band-aids (try/catch the handler, or clamp the index to len-1) STOP
# the 500s but leave p50 off-by-one WRONG. Only correcting the formula (`ceil(p*N)-1`) restores
# correct values. The grader asserts p50 correctness on a known array where clamp/try-catch still
# return the wrong value -> STOPPING AT THE BAND-AID FAILS. See tasks/incident-response.toml.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/incident-response
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/incident-response}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = coordinate-only, owns NO repo
W="$SB/worker"; mkdir -p "$W/src" "$W/test" "$W/data"

echo "== worker repo: pulse metrics service, with the off-by-one percentile bug =="
cat > "$W/src/stats.js" <<'JS'
// Aggregate metric statistics for the pulse service.
//
// Percentiles use the NEAREST-RANK method: the p-quantile is the sample at
// 1-based rank ceil(p * N) in the ascending-sorted values, i.e. the
// (ceil(p*N))-th smallest sample. (So p50 of 15 sorted samples is the 8th.)
export function percentile(values, p) {
  const sorted = [...values].sort((a, b) => a - b);
  const rank = Math.ceil(p * sorted.length); // 1-based nearest rank
  return sorted[rank];                        // returns the rank-th sample (0-based indexing)
}

// Summary stats for a metric's recorded values.
export function computeStats(values) {
  const count = values.length;
  const sum = values.reduce((a, b) => a + b, 0);
  const avg = count ? sum / count : 0;
  return {
    count,
    sum,
    avg,
    p50: percentile(values, 0.5),
    p95: percentile(values, 0.95),
  };
}
JS

cat > "$W/src/store.js" <<'JS'
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dir = dirname(fileURLToPath(import.meta.url));

// In-memory event store, seeded from data/events.json on boot ("prod" state).
const events = JSON.parse(readFileSync(join(__dir, "..", "data", "events.json"), "utf8"));

export function record(metric, value) {
  (events[metric] ??= []).push(value);
}

export function valuesFor(metric) {
  return events[metric] ?? [];
}

export function metrics() {
  return Object.keys(events);
}
JS

cat > "$W/src/server.js" <<'JS'
import { createServer } from "node:http";
import { computeStats } from "./stats.js";
import { record, valuesFor } from "./store.js";

// GET  /stats?metric=NAME   -> { count, sum, avg, p50, p95 } (numbers formatted to 2 decimals)
// POST /event  {metric,value} -> records a value
export function handle(req, res) {
  const url = new URL(req.url, "http://localhost");
  if (req.method === "GET" && url.pathname === "/stats") {
    const metric = url.searchParams.get("metric");
    const s = computeStats(valuesFor(metric));
    const body = JSON.stringify({
      metric,
      count: s.count,
      sum: s.sum,
      avg: s.avg.toFixed(2),
      p50: s.p50.toFixed(2), // TypeError if percentile returned undefined (small metric) -> 500
      p95: s.p95.toFixed(2),
    });
    res.writeHead(200, { "content-type": "application/json" });
    return res.end(body);
  }
  res.writeHead(404).end();
}

export function start(port = 8080) {
  const server = createServer((req, res) => {
    try {
      handle(req, res);
    } catch (err) {
      // Prod logs show: TypeError: Cannot read properties of undefined (reading 'toFixed')
      console.error(`[pulse] 500 on ${req.method} ${req.url}:`, err.message);
      res.writeHead(500, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: "internal error" }));
    }
  });
  server.listen(port, () => console.log(`[pulse] listening on :${port}`));
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) start();
JS

# Seeded "prod" state: latency + checkout are LOW-sample (crash p95); orders is healthy (works).
cat > "$W/data/events.json" <<'JSON'
{
  "latency": [120, 85, 340, 95, 110, 78, 200, 155, 90, 130, 410, 88, 175, 102, 145],
  "checkout": [3, 5, 2, 8, 4, 6, 3, 7],
  "orders": [12, 9, 15, 22, 8, 30, 11, 14, 19, 7, 25, 13, 10, 18, 21, 16, 6, 27, 17, 20, 24, 5, 23, 26]
}
JSON

# Existing suite: GREEN. Exercises only the healthy 24-sample `orders` metric; asserts count/sum/avg
# exactly and percentiles LOOSELY (a number, in-range, p95>=p50) — so the off-by-one never trips it.
cat > "$W/test/stats.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { computeStats, percentile } from "../src/stats.js";

const ORDERS = [12, 9, 15, 22, 8, 30, 11, 14, 19, 7, 25, 13, 10, 18, 21, 16, 6, 27, 17, 20, 24, 5, 23, 26];

test("computeStats: count/sum/avg", () => {
  const s = computeStats(ORDERS);
  assert.equal(s.count, 24);
  assert.equal(s.sum, 398);
  assert.equal(s.avg, 398 / 24);
});

test("computeStats: percentiles are in-range numbers", () => {
  const s = computeStats(ORDERS);
  assert.equal(typeof s.p50, "number");
  assert.equal(typeof s.p95, "number");
  assert.ok(s.p50 >= 5 && s.p50 <= 30);
  assert.ok(s.p95 >= s.p50);
});

test("percentile: returns a sample value", () => {
  assert.ok(ORDERS.includes(percentile(ORDERS, 0.5)));
});
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "pulse",
  "version": "1.4.0",
  "private": true,
  "type": "module",
  "description": "A tiny in-memory metrics service (event ingest + /stats percentiles).",
  "main": "src/server.js",
  "scripts": { "start": "node src/server.js", "test": "node --test" }
}
JSON

cat > "$W/README.md" <<'MD'
# pulse

A tiny in-memory metrics service.

- `POST /event` `{ "metric": "latency", "value": 123 }` — record a sample.
- `GET /stats?metric=latency` — `{ count, sum, avg, p50, p95 }`.

Percentiles use the **nearest-rank** method: the p-quantile is the sample at 1-based
rank `ceil(p * N)` in the ascending-sorted values (e.g. p50 of 15 samples is the 8th smallest).

State is seeded from `data/events.json` on boot. Run the tests with `npm test`; start with `npm start`.
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
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "pulse: metrics service v1.4.0"
git -C "$W" config user.name  "ir-oncall"
git -C "$W" config user.email "ir-oncall@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo
echo "== VALIDATE invariants (suite green, incident reproduces, bug is real, fix is well-defined) =="
# 1) existing suite GREEN
( cd "$W" && node --test >/dev/null 2>&1 && echo "  [ok] suite GREEN (as designed)" || { echo "  [!!] suite unexpectedly RED"; exit 1; } )

# 2) the incident reproduces: /stats on a small metric crashes (undefined.toFixed)
CRASH=$(cd "$W" && node --input-type=module -e '
import { computeStats } from "./src/stats.js";
const latency=[120,85,340,95,110,78,200,155,90,130,410,88,175,102,145];
const s=computeStats(latency);
try { s.p95.toFixed(2); console.log("NO-CRASH p95="+s.p95); }
catch(e){ console.log("CRASH "+e.constructor.name+": "+e.message); }
' 2>&1)
echo "  repro /stats?metric=latency (15 samples): $CRASH"
case "$CRASH" in CRASH*) echo "  [ok] incident reproduces (500 on small metric)";; *) echo "  [!!] expected a crash, got: $CRASH"; exit 1;; esac

# 3) the bug is REAL even when it doesn't crash: p50 is off-by-one vs nearest-rank ground truth
DISCR=$(cd "$W" && node --input-type=module -e '
import { percentile } from "./src/stats.js";
const a=[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];      // sorted; nearest-rank p50 = rank ceil(7.5)=8 -> value 8
const buggy=percentile(a,0.5);
const correct=[...a].sort((x,y)=>x-y)[Math.ceil(0.5*a.length)-1];
console.log("buggy_p50="+buggy+" correct_p50="+correct+(buggy!==correct?" DIFFERS":" SAME"));
' 2>&1)
echo "  discriminator p50([1..15]): $DISCR"
case "$DISCR" in *DIFFERS*) echo "  [ok] off-by-one is observable (band-aids that only stop the crash will fail this)";; *) echo "  [!!] p50 not off-by-one — discriminator broken"; exit 1;; esac

# 4) the ROOT fix is well-defined + sufficient: `sorted[ceil(p*N)-1]` fixes BOTH crash and correctness
FIX=$(cd "$W" && node --input-type=module -e '
const P=(values,p)=>{const s=[...values].sort((a,b)=>a-b);return s[Math.ceil(p*s.length)-1];};
const latency=[120,85,340,95,110,78,200,155,90,130,410,88,175,102,145];
const a=[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];
const p95=P(latency,0.95), p50=P(a,0.5);
console.log("fixed: latency.p95="+p95+" (defined? "+(p95!==undefined)+"), [1..15].p50="+p50+" (==8? "+(p50===8)+")");
' 2>&1)
echo "  root fix check: $FIX"
case "$FIX" in *"defined? true"*"==8? true"*) echo "  [ok] root fix (ceil(p*N)-1) resolves crash AND corrects p50";; *) echo "  [!!] root fix formula wrong"; exit 1;; esac

echo
echo "SANDBOX READY: $SB   (worker base $BASE; author ir-oncall)"
echo "  worker/  pulse (owned by ir-oncall; GREEN suite; /stats 500s in prod on small metrics)"
echo "  sup/     coordinate-only (ir-sup cwd; owns no repo)"
echo "next: compose personas + wire agents (sup=bypass, oncall=auto), seed the incident kick into ir-sup inbox, spin."
