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
