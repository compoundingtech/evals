import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { loadActive, makeCandidate, refreshAndConverge } from "../src/index.js";

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

test("invalid refresh preserves local active state and service identity", async () => {
  await withRoot(async (root) => {
    await stage(root, makeCandidate({ host: "north", version: 1, services: ["api"] }));
    const first = await refreshAndConverge({
      root,
      host: "north",
      controllerId: "one",
    });
    await stage(root, { ...makeCandidate({
      host: "north",
      version: 2,
      services: ["api", "queue"],
    }), complete: false });
    const second = await refreshAndConverge({
      root,
      host: "north",
      controllerId: "two",
      peerReachable: false,
    });
    assert.equal(second.health, "healthy");
    assert.equal((await loadActive(root, "north")).version, 1);
    assert.equal(second.registry.services[0].instanceId, first.registry.services[0].instanceId);
    assert.equal(second.actions[0].type, "adopt");
  });
});

test("two hosts keep independent active versions", async () => {
  await withRoot(async (root) => {
    for (const [host, version] of [["north", 3], ["south", 7]]) {
      await stage(root, makeCandidate({ host, version, services: [host] }));
      await refreshAndConverge({ root, host, controllerId: "one" });
    }
    assert.equal((await loadActive(root, "north")).version, 3);
    assert.equal((await loadActive(root, "south")).version, 7);
  });
});
