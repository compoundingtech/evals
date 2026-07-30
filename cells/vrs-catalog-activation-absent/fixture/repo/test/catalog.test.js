import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { makeCandidate, refreshAndConverge } from "../src/index.js";

async function withRoot(fn) {
  const root = await mkdtemp(path.join(os.tmpdir(), "harbor-test-"));
  try {
    await fn(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

async function stage(root, candidate) {
  const directory = path.join(root, "incoming", candidate.host);
  await mkdir(directory, { recursive: true });
  await writeFile(
    path.join(directory, "candidate.json"),
    `${JSON.stringify(candidate, null, 2)}\n`,
  );
}

test("a complete candidate activates and starts its declared services", async () => {
  await withRoot(async (root) => {
    await stage(root, makeCandidate({
      host: "north",
      version: 1,
      services: ["api", "queue"],
    }));
    const result = await refreshAndConverge({
      root,
      host: "north",
      controllerId: "controller-a",
    });
    assert.equal(result.activation, "activated");
    assert.deepEqual(
      result.registry.services.map((service) => service.name),
      ["api", "queue"],
    );
    assert.deepEqual(
      JSON.parse(await readFile(path.join(root, "active", "catalog.json"), "utf8"))
        .services,
      ["api", "queue"],
    );
  });
});
