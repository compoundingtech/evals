import test from "node:test";
import assert from "node:assert/strict";
import { legacyTitle } from "../src/legacy/title.js";

test("legacyTitle prefers the heading", () => {
  assert.equal(legacyTitle({ id: 1, heading: "Heading", body: "body" }), "Heading");
});

test("legacyTitle falls back to the first body line", () => {
  assert.equal(legacyTitle({ id: 2, heading: "", body: "first\nsecond" }), "first");
});
