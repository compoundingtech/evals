import assert from "node:assert/strict";
import test from "node:test";

import { countPassing, summarizeChecks } from "../src/summary.js";

test("counts passing checks", () => {
  assert.equal(
    countPassing([{ name: "db", ok: true }, { name: "queue", ok: false }]),
    1,
  );
});

test("summarizes passing and failing checks", () => {
  assert.deepEqual(
    summarizeChecks([{ name: "db", ok: true }, { name: "queue", ok: false }]),
    { total: 2, passing: 1, failing: 1 },
  );
  assert.throws(() => summarizeChecks([{ name: "db" }]), /boolean ok/);
});

