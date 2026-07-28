import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

test("health-summary command emits compact JSON and exits 2 for failures", () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "health-summary-"));
  try {
    const input = path.join(scratch, "checks.json");
    fs.writeFileSync(input, '[{"name":"db","ok":true},{"name":"queue","ok":false}]\n');
    const result = spawnSync(
      process.execPath,
      [fileURLToPath(new URL("../bin/health-summary.js", import.meta.url)), input],
      { encoding: "utf8" },
    );
    assert.equal(result.status, 2);
    assert.equal(result.stdout, '{"total":2,"passing":1,"failing":1}\n');
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});
