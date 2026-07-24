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
