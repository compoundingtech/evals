#!/usr/bin/env bash
# JUDGE (the discriminator): a FRESH `claude --print` cold reader gets ONLY the team's docs + the checkout
# library as a MANGLED BLACK BOX (input identifiers stripped, so peeking reveals nothing about the
# cents/basis-points/immutability/seal contracts) + a task in HUMAN terms ($12.50, 8% tax). It must write
# the library's total() to result.json. PASS iff totalCents === 1944 — i.e. the docs conveyed every
# load-bearing contract. (Good docs -> 1944; docs missing a contract -> silently wrong.)
#
# PASS (exit 0): the cold reader computes totalCents === 1944 from the docs alone.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
R="$(mktemp -d)/reader"; EXPECT_TOTAL=1944
rm -rf "$R"; mkdir -p "$R/node_modules/checkout"

# 1) the library as a MANGLED BLACK BOX (same behavior; input identifiers hidden). Output keys stay
#    (they're the documented return shape).
cat > "$R/node_modules/checkout/index.js" <<'JS'
const P = { SAVE10: 0.10, HALF: 0.50 };
export function create() { return new C([], null, 0, false); }
class C {
  constructor(a, b, c, d) { this.x = a; this.y = b; this.z = c; this.w = d; }
  add(a, b, c = 1) { return new C([...this.x, { n: a, u: b, q: c }], this.y, this.z, this.w); }
  applyPromo(a) { return new C([...this.x], a, this.z, this.w); }
  setTax(a) { return new C([...this.x], this.y, a, this.w); }
  seal() { return new C([...this.x], this.y, this.z, true); }
  total() {
    const s = this.x.reduce((t, i) => t + i.u * i.q, 0);
    if (!this.w) return { subtotalCents: s, discountCents: 0, taxCents: 0, totalCents: s };
    const f = this.y && P[this.y] ? P[this.y] : 0;
    const d = Math.round(s * f); const tx = s - d; const t = Math.round((tx * this.z) / 10000);
    return { subtotalCents: s, discountCents: d, taxCents: t, totalCents: tx + t };
  }
}
JS
cat > "$R/node_modules/checkout/package.json" <<'JSON'
{ "name":"checkout","version":"0.3.0","type":"module","main":"index.js","exports":"./index.js" }
JSON

# 2) the team's docs — the ONLY API reference the reader gets.
cp "$W/README.md" "$R/README.md" 2>/dev/null || true
[ -d "$W/docs" ] && cp -r "$W/docs" "$R/docs"
cat > "$R/package.json" <<'JSON'
{ "name":"reader","private":true,"type":"module" }
JSON

# 3) the task — HUMAN terms; the docs must bridge to the library's conventions.
cat > "$R/task.md" <<'MD'
# Task
Use the `checkout` library (installed as the `checkout` package: `import { create } from "checkout"`).
Learn the API from **README.md / the docs/ folder ONLY** — treat the compiled library as a black box;
do not try to reverse-engineer its source.

Build this order and compute the total:
- "Widget" — $12.50 each, quantity 1
- "Gadget" — $3.75 each, quantity 2
- Apply promo code: SAVE10
- Apply sales tax of 8%

Write the exact object returned by the cart's `total()` to `./result.json` (as JSON).
MD

# 4) pre-trust the reader sandbox + run a FRESH headless agent (no bus, no persona, no memory).
sid="$(uuidgen | tr 'A-Z' 'a-z')"
python3 - "$R" <<'PY' 2>/dev/null || true
import json, os, sys
p = os.path.expanduser("~/.claude.json")
d = json.load(open(p)) if os.path.exists(p) else {}
e = d.setdefault("projects", {}).setdefault(sys.argv[1], {})
e["hasTrustDialogAccepted"] = True; e["hasCompletedProjectOnboarding"] = True
json.dump(d, open(p, "w"), indent=2)
PY
echo "  running fresh cold-reader agent (docs-only)..."
( cd "$R" && timeout 300 claude --print --permission-mode bypassPermissions --session-id "$sid" \
  "Read task.md and do exactly what it asks. Learn the checkout API from README.md / docs only; treat the library as a black box. Write ./result.json." \
  > "$R/reader.log" 2>&1 ) || echo "  (reader print exited nonzero/timed out; grading result.json anyway)"

# 5) grade
if [ -f "$R/result.json" ]; then
  echo "  result.json: $(tr -d '\n' < "$R/result.json" | head -c 300)"
  GOT=$(node -e 'const fs=require("fs");const r=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log(r.totalCents ?? (r.total&&r.total.totalCents) ?? r.total ?? "")' "$R/result.json" 2>/dev/null)
  echo "  totalCents got=$GOT  expected=$EXPECT_TOTAL"
  if [ "$GOT" = "$EXPECT_TOTAL" ]; then
    echo "PASS: cold reader succeeded using ONLY the docs — the docs WORK (all load-bearing contracts conveyed)."; rm -rf "$(dirname "$R")"; exit 0
  else
    echo "FAIL: cold reader got the wrong total — docs insufficient/inaccurate (a load-bearing contract wasn't conveyed)."; rm -rf "$(dirname "$R")"; exit 1
  fi
else
  echo "FAIL: cold reader produced no result.json — the docs didn't enable use. (see reader.log)"; rm -rf "$(dirname "$R")"; exit 1
fi
