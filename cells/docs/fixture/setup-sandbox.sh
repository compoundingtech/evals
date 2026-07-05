#!/usr/bin/env bash
# Materialize the Docs ("Explain it") eval sandbox. A small `checkout` cart library with THREE
# non-obvious, SILENT-FAILURE contracts that a newcomer cannot guess from names/signatures and that
# only good docs reveal:
#   C1. money is in INTEGER CENTS, and tax is in BASIS POINTS (825 = 8.25%) — pass dollars/percent
#       and you're silently 100x / off.
#   C2. the API is IMMUTABLE + FLUENT — add/applyPromo/setTax/seal each return a NEW cart; if you
#       don't use the return value the call silently does nothing (promo/tax/items lost).
#   C3. you must call seal() BEFORE total() — before sealing, total() reports the raw item subtotal
#       only (no promo, no tax). Skip it and total() is silently wrong (no error).
# The functional suite is GREEN and exercises all three, so the contracts are discoverable by reading
# the code+tests — the doc-writer's job is to EXTRACT and EXPLAIN them for a cold reader.
#
# DISCRIMINATOR (docs, suite #10): a FRESH cold-reader agent (see cold-reader.sh) gets ONLY the team's
# docs (no source) and must compute a checkout total. Good docs (all 3 contracts + return shape + an
# example) -> reader succeeds (totalCents=1944). Docs that omit a contract -> reader silently wrong.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/docs
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/docs}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = coordinate-only, owns NO repo
W="$SB/worker"; mkdir -p "$W/src" "$W/test"

echo "== worker repo: checkout lib (3 non-obvious contracts), inadequate stub README =="
cat > "$W/src/checkout.js" <<'JS'
// checkout — cart + totals.
const PROMOS = { SAVE10: 0.10, HALF: 0.50 }; // promo code -> fraction off the subtotal

export function create() {
  return new Cart([], null, 0, false);
}

class Cart {
  constructor(items, promo, taxBps, sealed) {
    this._items = items;
    this._promo = promo;
    this._taxBps = taxBps;
    this._sealed = sealed;
  }
  add(name, unitCents, qty = 1) {
    return new Cart([...this._items, { name, unitCents, qty }], this._promo, this._taxBps, this._sealed);
  }
  applyPromo(code) {
    return new Cart([...this._items], code, this._taxBps, this._sealed);
  }
  setTax(rateBps) {
    return new Cart([...this._items], this._promo, rateBps, this._sealed);
  }
  seal() {
    return new Cart([...this._items], this._promo, this._taxBps, true);
  }
  total() {
    const subtotalCents = this._items.reduce((s, i) => s + i.unitCents * i.qty, 0);
    if (!this._sealed) {
      return { subtotalCents, discountCents: 0, taxCents: 0, totalCents: subtotalCents };
    }
    const frac = this._promo && PROMOS[this._promo] ? PROMOS[this._promo] : 0;
    const discountCents = Math.round(subtotalCents * frac);
    const taxableCents = subtotalCents - discountCents;
    const taxCents = Math.round((taxableCents * this._taxBps) / 10000);
    return { subtotalCents, discountCents, taxCents, totalCents: taxableCents + taxCents };
  }
}
JS

# GREEN functional suite — exercises all three contracts (so they're discoverable), but it's CODE,
# not docs. The doc-writer must turn this understanding into prose a newcomer can use.
cat > "$W/test/checkout.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { create } from "../src/checkout.js";

test("cents + basis points, promo + tax, sealed", () => {
  const cart = create()
    .add("Widget", 1250, 1)
    .add("Gadget", 375, 2)
    .applyPromo("SAVE10")
    .setTax(800)
    .seal();
  assert.deepEqual(cart.total(), { subtotalCents: 2000, discountCents: 200, taxCents: 144, totalCents: 1944 });
});

test("immutability: methods return a NEW cart; the original is unchanged", () => {
  const base = create().add("A", 500);
  base.applyPromo("HALF").setTax(1000); // return values intentionally discarded
  // base is untouched: unsealed total is the raw subtotal, no promo/tax
  assert.deepEqual(base.seal().total(), { subtotalCents: 500, discountCents: 0, taxCents: 0, totalCents: 500 });
});

test("seal() is required: total() before seal() reports the raw subtotal only", () => {
  const cart = create().add("A", 1000).applyPromo("SAVE10").setTax(1000);
  assert.deepEqual(cart.total(), { subtotalCents: 1000, discountCents: 0, taxCents: 0, totalCents: 1000 });
  assert.equal(cart.seal().total().totalCents, 990); // 1000 - 100 promo + 90 tax? -> 900+90=990
});

test("unknown promo code is a no-op discount", () => {
  const t = create().add("A", 1000).applyPromo("NOPE").setTax(0).seal().total();
  assert.equal(t.discountCents, 0);
  assert.equal(t.totalCents, 1000);
});
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "checkout",
  "version": "0.3.0",
  "private": true,
  "type": "module",
  "description": "A cart + checkout-totals library.",
  "main": "src/checkout.js",
  "exports": "./src/checkout.js",
  "scripts": { "test": "node --test" }
}
JSON

# Inadequate starting docs — the real task is to replace this with docs a newcomer can use.
cat > "$W/README.md" <<'MD'
# checkout

A cart + checkout-totals library. `create()` makes a cart; add items and get a total.

```
npm test
```
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
result.json
GI

echo "== git init worker repo (frozen base) + distinct author =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "checkout: cart library v0.3.0 (stub README)"
git -C "$W" config user.name  "doc-writer"
git -C "$W" config user.email "doc-writer@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo
echo "== VALIDATE invariants =="
# 1) suite GREEN
( cd "$W" && node --test >/dev/null 2>&1 && echo "  [ok] suite GREEN" || { echo "  [!!] suite RED"; exit 1; } )

# 2) the cold-reader's correct answer is well-defined (the documented, sealed path)
GOOD=$(cd "$W" && node --input-type=module -e '
import { create } from "./src/checkout.js";
const t = create().add("Widget",1250,1).add("Gadget",375,2).applyPromo("SAVE10").setTax(800).seal().total();
console.log(JSON.stringify(t));
')
echo "  correct (docs-following) total: $GOOD"
[ "$GOOD" = '{"subtotalCents":2000,"discountCents":200,"taxCents":144,"totalCents":1944}' ] \
  && echo "  [ok] expected cold-reader answer = 1944 breakdown" || { echo "  [!!] expected answer drifted"; exit 1; }

# 3) the contracts are LOAD-BEARING: naive/blind usages are silently WRONG (prove docs matter)
echo "  naive-blind failure modes (each must differ from 1944):"
cd "$W" && node --input-type=module -e '
import { create } from "./src/checkout.js";
const p=(o)=>o.totalCents;
// (a) forgot seal(): total() ignores promo+tax
console.log("   no-seal     totalCents=",p(create().add("Widget",1250,1).add("Gadget",375,2).applyPromo("SAVE10").setTax(800).total()));
// (b) discarded returns (assumed mutation): promo+tax+items lost
let c=create(); c.add("Widget",1250,1); c.add("Gadget",375,2); c.applyPromo("SAVE10"); c.setTax(800);
console.log("   discard-ret totalCents=",p(c.seal().total()));
// (c) dollars instead of cents, percent instead of bps
console.log("   dollars     totalCents=",p(create().add("Widget",12.5,1).add("Gadget",3.75,2).applyPromo("SAVE10").setTax(8).seal().total()));
'

echo
echo "SANDBOX READY: $SB   (worker base $BASE; author doc-writer)"
echo "  worker/  checkout lib (owned by doc-writer; GREEN suite; stub README — needs real docs)"
echo "  sup/     coordinate-only (doc-sup cwd; owns no repo)"
echo "next: compose personas + wire agents (sup=bypass, writer=auto), seed the docs kick, spin; then cold-reader.sh grades the docs held-out."
