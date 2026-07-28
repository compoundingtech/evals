import assert from "node:assert/strict";
import test from "node:test";

import { countPassing } from "../src/summary.js";

test("counts passing checks", () => {
  assert.equal(
    countPassing([{ name: "db", ok: true }, { name: "queue", ok: false }]),
    1,
  );
});

