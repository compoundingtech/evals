import assert from "node:assert/strict";
import {
  access,
  mkdtemp,
  mkdir,
  readFile,
  readdir,
  rm,
  unlink,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [mode, repository] = process.argv.slice(2);
if (!mode || !repository) throw new Error("usage: behavior.mjs MODE REPOSITORY");
const api = await import(pathToFileURL(`${repository}/src/index.js`));

async function withRoot(run) {
  const root = await mkdtemp(path.join(os.tmpdir(), "harbor-judge-"));
  try {
    await run(root);
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

async function removeCandidate(root, host) {
  await unlink(path.join(root, "incoming", host, "candidate.json")).catch(
    (error) => {
      if (error.code !== "ENOENT") throw error;
    },
  );
}

function candidate(host, version, services, overrides = {}) {
  return { ...api.makeCandidate({ host, version, services }), ...overrides };
}

function ids(result) {
  return new Map(
    result.registry.services.map((service) => [service.name, service.instanceId]),
  );
}

switch (mode) {
  case "activation":
    await withRoot(async (root) => {
      await stage(root, candidate("north", 5, ["api", "queue"]));
      const result = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-a",
      });
      assert.equal(result.activation, "activated");
      assert.equal(result.health, "healthy");
      assert.equal(result.active.host, "north");
      assert.equal(result.active.version, 5);
      assert.deepEqual(result.active.services, ["api", "queue"]);
      assert.deepEqual(await api.loadActive(root, "north"), result.active);
      assert.equal(await api.loadActive(root, "south"), null);
      assert.deepEqual(
        result.actions.map((action) => action.type),
        ["start", "start"],
      );
    });
    break;

  case "preservation":
    await withRoot(async (root) => {
      await stage(root, candidate("north", 5, ["api"]));
      const first = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-a",
      });
      const instance = ids(first).get("api");

      const cases = [
        async () => removeCandidate(root, "north"),
        async () => stage(root, candidate("north", 6, ["api", "queue"], {
          complete: false,
        })),
        async () => stage(root, candidate("north", 6, ["api", "queue"], {
          digest: "0".repeat(64),
        })),
        async () => stage(root, candidate("north", 4, ["other"])),
      ];
      let controller = 0;
      for (const arrange of cases) {
        await arrange();
        controller += 1;
        const result = await api.refreshAndConverge({
          root,
          host: "north",
          controllerId: `controller-${controller}`,
        });
        assert.equal(result.active.version, 5);
        assert.deepEqual(result.active.services, ["api"]);
        assert.equal(ids(result).get("api"), instance);
        assert.equal(result.actions.some((action) => action.type === "stop"), false);
      }
    });
    break;

  case "partition":
    await withRoot(async (root) => {
      for (const [host, version] of [["north", 6], ["south", 8]]) {
        await stage(root, candidate(host, version, [host]));
        await api.refreshAndConverge({ root, host, controllerId: "controller-a" });
      }
      const southBefore = JSON.stringify(await api.loadActive(root, "south"));
      await stage(root, candidate("north", 7, ["north", "edge"]));
      await stage(root, candidate("south", 9, ["south", "edge"], {
        complete: false,
      }));
      const north = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-b",
        peerReachable: false,
      });
      const south = await api.refreshAndConverge({
        root,
        host: "south",
        controllerId: "controller-b",
        peerReachable: false,
      });
      assert.equal(north.active.version, 7);
      assert.equal(south.active.version, 8);
      assert.equal(JSON.stringify(await api.loadActive(root, "south")), southBefore);
      assert.equal((await api.loadActive(root, "north")).host, "north");
      assert.equal((await api.loadActive(root, "south")).host, "south");
    });
    break;

  case "reachability":
    await withRoot(async (root) => {
      await stage(root, candidate("north", 1, ["api"]));
      const first = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-a",
      });
      const instance = ids(first).get("api");

      await stage(root, candidate("north", 2, ["api", "queue"]));
      const neutral = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-a",
        peerReachable: false,
      });
      assert.equal(neutral.health, "healthy");
      assert.equal(neutral.active.version, 2);

      await stage(root, candidate("north", 3, ["other"]));
      const blocked = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-b",
        peerReachable: false,
        explicitPeerDependency: true,
      });
      assert.equal(blocked.health, "blocked");
      assert.equal(blocked.active.version, 2);
      assert.equal(ids(blocked).get("api"), instance);
      assert.equal(blocked.actions.some((action) => action.type === "stop"), false);
    });
    break;

  case "crash":
    await withRoot(async (root) => {
      await stage(root, candidate("north", 1, ["api"]));
      await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-a",
      });
      await stage(root, candidate("north", 2, ["api", "queue"]));

      let injected = false;
      try {
        await api.refreshAndConverge({
          root,
          host: "north",
          controllerId: "controller-a",
          afterStage: async () => {
            injected = true;
            throw new Error("injected interruption");
          },
        });
      } catch (error) {
        assert.match(error.message, /injected interruption/);
      }
      assert.equal(injected, true);
      assert.equal((await api.loadActive(root, "north")).version, 1);

      const retried = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-a",
      });
      assert.equal(retried.active.version, 2);
      assert.deepEqual(retried.active.services, ["api", "queue"]);
      assert.equal(retried.active.digest, api.candidateDigest(retried.active));
    });
    break;

  case "adoption":
    await withRoot(async (root) => {
      await stage(root, candidate("north", 1, ["api", "queue"]));
      const first = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-a",
      });
      const original = ids(first);
      await removeCandidate(root, "north");
      const replacement = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-b",
      });
      assert.deepEqual(ids(replacement), original);
      assert.deepEqual(
        replacement.actions.map((action) => action.type),
        ["adopt", "adopt"],
      );

      await stage(root, candidate("north", 2, ["api", "web"]));
      const changed = await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-c",
      });
      assert.equal(ids(changed).get("api"), original.get("api"));
      assert.equal(changed.actions.some((item) =>
        item.type === "stop" && item.service === "queue"), true);
      assert.equal(changed.actions.some((item) =>
        item.type === "start" && item.service === "web"), true);
    });
    break;

  case "coupling":
    await withRoot(async (root) => {
      for (const host of ["north", "south"]) {
        await stage(root, candidate(host, 1, [host]));
        await api.refreshAndConverge({ root, host, controllerId: "controller-a" });
      }
      const southActive = JSON.stringify(await api.loadActive(root, "south"));
      const southRuntime = await readFile(
        path.join(root, "runtime", "south.json"),
        "utf8",
      );
      await stage(root, candidate("north", 2, ["north", "edge"]));
      await api.refreshAndConverge({
        root,
        host: "north",
        controllerId: "controller-b",
        peerReachable: false,
      });
      assert.equal(JSON.stringify(await api.loadActive(root, "south")), southActive);
      assert.equal(
        await readFile(path.join(root, "runtime", "south.json"), "utf8"),
        southRuntime,
      );
      await assert.rejects(access(path.join(root, "active", "catalog.json")));
      const activeEntries = await readdir(path.join(root, "active"));
      assert.deepEqual(activeEntries.sort(), ["north", "south"]);
    });
    break;

  default:
    throw new Error(`unknown behavior mode ${mode}`);
}

process.stdout.write(`PASS: ${mode} behavioral gate\n`);
