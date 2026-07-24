#!/usr/bin/env bash
# JUDGE (hard): the returned values are CORRECT (root cause fixed, not just masked to non-500). Ground truth
# is computed independently (nearest-rank percentile) from the FROZEN base data — an off-by-one band-aid
# that stops the 500 but returns the wrong percentile still fails here.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W/.git" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)
CORR=$(cd "$W" && BASE="$BASE" node --input-type=module -e '
import { computeStats } from "./src/stats.js";
import { execSync } from "node:child_process";
const base = process.env.BASE;
const data = JSON.parse(execSync(`git show ${base}:data/events.json`, {encoding:"utf8"}));
const truth = (vals,p)=>{const s=[...vals].sort((a,b)=>a-b);return s[Math.ceil(p*s.length)-1];};
const cases = [
  ["latency p95", computeStats(data.latency).p95, truth(data.latency,0.95)],
  ["latency p50", computeStats(data.latency).p50, truth(data.latency,0.50)],
  ["[1..15] p50", computeStats([...Array(15)].map((_,i)=>i+1)).p50, 8],
];
let allok=true;
for (const [name,got,want] of cases){ const good = Number.isFinite(got) && got===want; if(!good) allok=false; console.log(`  ${good?"ok":"XX"} ${name}: got=${got} want=${want}`); }
console.log(allok ? "CORRECT" : "WRONG");
' 2>&1)
echo "$CORR" | sed '/^CORRECT$\|^WRONG$/d'
case "$CORR" in
  *CORRECT*) echo "PASS: returned values are CORRECT (root cause fixed, not masked)"; exit 0;;
  *) echo "FAIL: values WRONG or endpoint still broken — band-aid or unfixed (see rows above)"; exit 1;;
esac
