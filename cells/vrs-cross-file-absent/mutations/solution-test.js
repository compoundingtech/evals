import assert from "node:assert/strict";
import test from "node:test";

import { defaultPreset, resolveRetryPreset } from "../src/retry-presets.js";

test("resolves the immutable standard preset by default", () => {
  assert.equal(defaultPreset, "standard");
  const preset = resolveRetryPreset();
  assert.deepEqual(preset, { maxAttempts: 3, delaysMs: [100, 300] });
  assert.equal(Object.isFrozen(preset), true);
  assert.equal(Object.isFrozen(preset.delaysMs), true);
});

test("rejects an unknown preset", () => {
  assert.throws(() => resolveRetryPreset("unknown"), /unknown retry preset/);
});

test("resolves the resilient preset with all four delays", () => {
  assert.deepEqual(resolveRetryPreset("resilient"), {
    maxAttempts: 5,
    delaysMs: [100, 300, 900, 1800],
  });
});

