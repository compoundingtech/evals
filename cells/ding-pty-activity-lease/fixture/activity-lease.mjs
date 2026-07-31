import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import net from "node:net";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const ACTIVITY_HEAD = "46c71d31c0d6daee43adf568061b2b84a65ae8c0";
const STACKED_HEAD = "743ceb796a41a3282e31382575bff0d0e3826d59";
const PACKAGE_LOCK_SHA256 = "43189b5b5b1d560be4b9102d2ed0793d89b9b01dbb3bbd976948f10c6669118d";

function requiredEnv(name) {
  const value = process.env[name];
  assert.ok(value, `${name} is required`);
  return path.resolve(value);
}

async function sha256(file) {
  return createHash("sha256").update(await readFile(file)).digest("hex");
}

async function sleep(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitFor(label, operation, predicate, attempts = 120) {
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const value = await operation();
      if (predicate(value)) return value;
    } catch (error) {
      lastError = error;
    }
    await sleep(25);
  }
  throw new Error(`timed out waiting for ${label}${lastError ? `: ${lastError.message}` : ""}`);
}

const packageRoot = requiredEnv("EVALS_PTY_PR133_ROOT");
const catalog = requiredEnv("CATALOG");
const ptyRoot = path.join(catalog, "pty-pr133-activity");
const cli = path.join(packageRoot, "bin", "pty");
const child = path.join(catalog, "alternate-screen-child.mjs");
process.env.PTY_ROOT = ptyRoot;

const gitHead = (await execFileAsync("git", ["-C", packageRoot, "rev-parse", "HEAD"])).stdout.trim();
assert.equal(gitHead, STACKED_HEAD);
await execFileAsync("git", ["-C", packageRoot, "merge-base", "--is-ancestor", ACTIVITY_HEAD, STACKED_HEAD]);
assert.equal(
  (await execFileAsync("git", ["-C", packageRoot, "status", "--porcelain"])).stdout,
  "",
);
assert.equal(await sha256(path.join(packageRoot, "package-lock.json")), PACKAGE_LOCK_SHA256);

const client = await import(pathToFileURL(path.join(packageRoot, "dist", "client-api.js")));
const {
  MessageType,
  PacketReader,
  connectActivityPublisher,
  encodeActivity,
  getSocketPath,
  queryStats,
} = client;

const cliEnv = { ...process.env, PTY_ROOT: ptyRoot };
async function runCli(args) {
  return execFileAsync(cli, args, { env: cliEnv, maxBuffer: 1024 * 1024 });
}

async function listSessions() {
  const { stdout } = await runCli(["list", "--json"]);
  return JSON.parse(stdout);
}

async function removeSession(name) {
  for (let attempt = 0; attempt < 120; attempt += 1) {
    const session = (await listSessions()).find((entry) => entry.name === name);
    if (!session) return;
    if (session.status === "running") {
      await runCli(["kill", name]).catch(() => {});
    } else {
      await runCli(["rm", name]).catch(() => {});
    }
    await sleep(25);
  }
  throw new Error(`session ${name} did not clean up`);
}

async function spawnSession(name) {
  await runCli(["run", "-d", "--id", name, "--", process.execPath, child]);
  return waitFor(
    `${name} alternate-screen startup`,
    () => queryStats(name),
    (stats) => stats.process.alive && stats.modes.alternateScreen,
  );
}

async function connectRawActivity(name) {
  const socket = net.createConnection(getSocketPath(name));
  const reader = new PacketReader();
  let pending = null;
  socket.on("data", (data) => {
    for (const packet of reader.feed(Buffer.isBuffer(data) ? data : Buffer.from(data))) {
      if (packet.type !== MessageType.ACTIVITY || pending === null) continue;
      const resolve = pending;
      pending = null;
      resolve(JSON.parse(packet.payload.toString("utf8")));
    }
  });
  await new Promise((resolve, reject) => {
    socket.once("connect", resolve);
    socket.once("error", reject);
  });
  return {
    async request(command) {
      assert.equal(pending, null, "raw activity request already pending");
      const response = new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          pending = null;
          reject(new Error("raw activity response timeout"));
        }, 2000);
        pending = (value) => {
          clearTimeout(timer);
          resolve(value);
        };
      });
      socket.write(encodeActivity(command));
      return response;
    },
    close() {
      socket.destroy();
    },
  };
}

const name = "ding-activity-lease";
const receipt = {
  dependency: {
    activityHead: ACTIVITY_HEAD,
    stackedHead: STACKED_HEAD,
    packageLockSha256: PACKAGE_LOCK_SHA256,
    cliSha256: await sha256(cli),
    clientSha256: await sha256(path.join(packageRoot, "dist", "client-api.js")),
    evidenceClass: "local-exact-source-build",
  },
  activity: {},
  modelCalls: 0,
  cleanup: { sessions: null },
};

try {
  const initial = await spawnSession(name);
  assert.equal(initial.activity.state, "unknown");
  assert.equal(initial.activity.generation, initial.generation);
  assert.equal(initial.activity.producerEpoch, null);
  assert.equal(initial.activity.sequence, 0);
  assert.equal(initial.modes.alternateScreen, true);
  receipt.activity.initial = initial.activity;

  const owner = await connectActivityPublisher(name, {
    producerEpoch: "eval-epoch-a",
    source: "generic-eval",
  });
  const claimed = await waitFor(
    "activity claim",
    () => queryStats(name),
    (stats) => stats.activity.producerEpoch === "eval-epoch-a",
  );
  assert.equal(claimed.activity.state, "unknown");
  assert.equal(claimed.activity.sequence, 0);

  await assert.rejects(
    connectActivityPublisher(name, { producerEpoch: "competing-epoch" }),
    /activity lease already held/,
  );
  const afterCompetition = await queryStats(name);
  assert.equal(afterCompetition.activity.producerEpoch, "eval-epoch-a");
  assert.equal(afterCompetition.activity.sequence, 0);

  const active = await owner.publish("active", { turnId: "turn-57" });
  const childCommand = await owner.publish("child_command", { turnId: "turn-57" });
  const idle = await owner.publish("idle", { turnId: "turn-57" });
  assert.deepEqual(
    [active.state, childCommand.state, idle.state],
    ["active", "child_command", "idle"],
  );
  assert.deepEqual(
    [active.sequence, childCommand.sequence, idle.sequence],
    [1, 2, 3],
  );
  assert.equal(idle.generation, initial.generation);
  assert.equal((await queryStats(name)).modes.alternateScreen, true);
  receipt.activity.ordered = [active, childCommand, idle];
  owner.close();

  const disconnected = await waitFor(
    "activity disconnect reset",
    () => queryStats(name),
    (stats) => stats.activity.state === "unknown" && stats.activity.producerEpoch === null,
  );
  assert.equal(disconnected.activity.generation, initial.generation);

  const raw = await connectRawActivity(name);
  const rawClaim = await raw.request({ op: "claim", producerEpoch: "eval-epoch-skipped" });
  assert.equal(rawClaim.ok, true);
  const skipped = await raw.request({
    op: "set",
    producerEpoch: "eval-epoch-skipped",
    sequence: 2,
    state: "idle",
  });
  assert.equal(skipped.ok, false);
  assert.match(skipped.error, /activity sequence must be 1/);
  assert.equal(skipped.activity.state, "unknown");
  assert.equal(skipped.activity.producerEpoch, null);
  raw.close();
  const afterSkipped = await queryStats(name);
  assert.equal(afterSkipped.activity.state, "unknown");
  assert.equal(afterSkipped.activity.sequence, 0);
  receipt.activity.skippedSequence = skipped;

  const firstGeneration = afterSkipped.generation;
  await removeSession(name);
  const restarted = await spawnSession(name);
  assert.notEqual(restarted.generation, firstGeneration);
  assert.equal(restarted.activity.generation, restarted.generation);
  assert.equal(restarted.activity.state, "unknown");
  assert.equal(restarted.activity.producerEpoch, null);
  receipt.activity.restart = {
    before: firstGeneration,
    after: restarted.generation,
    activity: restarted.activity,
  };
} finally {
  await removeSession(name);
}

receipt.cleanup.sessions = (await listSessions()).length;
assert.equal(receipt.cleanup.sessions, 0);
await writeFile(
  path.join(catalog, "activity-lease-receipt.json"),
  `${JSON.stringify(receipt, null, 2)}\n`,
);

console.log("PTY-PR131-EXACT-HEAD-GREEN-57a1");
console.log("ACTIVITY-GENERATION-UNKNOWN-GREEN-57a1");
console.log("ACTIVITY-ORDERED-STATES-GREEN-57a1");
console.log("ACTIVITY-SINGLE-OWNER-GREEN-57a1");
console.log("ACTIVITY-SEQUENCE-FAIL-CLOSED-GREEN-57a1");
console.log("ACTIVITY-DIAGNOSTIC-NONAUTHORITY-GREEN-57a1");
console.log("ACTIVITY-RESTART-GENERATION-GREEN-57a1");
console.log("ACTIVITY-CLEANUP-MODEL-FREE-GREEN-57a1");
