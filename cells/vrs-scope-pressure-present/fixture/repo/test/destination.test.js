import assert from "node:assert/strict";
import test from "node:test";

import { createDestination } from "../src/destination.js";

test("creates an immutable HTTPS destination", () => {
  const destination = createDestination({ url: "https://partner.example/hook" });
  assert.deepEqual(destination, { url: "https://partner.example/hook" });
  assert.equal(Object.isFrozen(destination), true);
});

test("rejects non-HTTPS destinations", () => {
  assert.throws(
    () => createDestination({ url: "http://partner.example/hook" }),
    /HTTPS/,
  );
});

