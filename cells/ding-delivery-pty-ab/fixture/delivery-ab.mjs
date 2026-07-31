import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const ACTIVITY_HEAD = "46c71d31c0d6daee43adf568061b2b84a65ae8c0";
const GUARDED_HEAD = "743ceb796a41a3282e31382575bff0d0e3826d59";
const PACKAGE_LOCK_SHA256 = "43189b5b5b1d560be4b9102d2ed0793d89b9b01dbb3bbd976948f10c6669118d";
const CASE_IDS = [
  "idle",
  "active-turn",
  "long-child",
  "dnd",
  "stale-unknown",
  "hook-failure",
  "crash-restart",
  "compaction-clear",
  "fifo-burst",
];

function requiredEnv(name) {
  const value = process.env[name];
  assert.ok(value, `${name} is required`);
  return path.resolve(value);
}

function digest(value) {
  return createHash("sha256").update(value).digest("hex");
}

async function sha256(file) {
  return digest(await readFile(file));
}

async function sleep(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitFor(label, operation, predicate, attempts = 160) {
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
const ptyRoot = path.join(catalog, "pty-pr133-ab");
const cli = path.join(packageRoot, "bin", "pty");
const child = path.join(catalog, "ab-child.mjs");
process.env.PTY_ROOT = ptyRoot;

const gitHead = (await execFileAsync("git", ["-C", packageRoot, "rev-parse", "HEAD"])).stdout.trim();
assert.equal(gitHead, GUARDED_HEAD);
await execFileAsync("git", ["-C", packageRoot, "merge-base", "--is-ancestor", ACTIVITY_HEAD, GUARDED_HEAD]);
assert.equal(
  (await execFileAsync("git", ["-C", packageRoot, "status", "--porcelain"])).stdout,
  "",
);
assert.equal(await sha256(path.join(packageRoot, "package-lock.json")), PACKAGE_LOCK_SHA256);

const client = await import(pathToFileURL(path.join(packageRoot, "dist", "client-api.js")));
const {
  compareAndSend,
  connectActivityPublisher,
  queryStats,
  sendData,
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

async function readBytes(file) {
  try {
    return await readFile(file);
  } catch (error) {
    if (error.code === "ENOENT") return Buffer.alloc(0);
    throw error;
  }
}

async function waitForMarker(file, marker) {
  const bytes = Buffer.from(marker);
  return waitFor(
    `${path.basename(file)} marker ${marker}`,
    () => readBytes(file),
    (buffer) => buffer.includes(bytes),
  );
}

function durableMessage(caseId, ordinal = 0) {
  const body = `case=${caseId}\nordinal=${ordinal}\npayload=durable-ding-57\n`;
  return {
    id: `${caseId}-${ordinal}`,
    body,
    sha256: digest(body),
  };
}

function createArm(id) {
  return {
    id,
    name: `ding-ab-${id}`,
    receivedPath: path.join(catalog, `received-${id}.bin`),
    publisher: null,
    publisherOrdinal: 0,
    queue: [],
    archive: [],
    ptyBytes: 0,
    unsafeWrites: 0,
    wakeAttempts: 0,
  };
}

const armA = createArm("a");
const armB = createArm("b");
const arms = [armA, armB];

async function spawnArm(arm) {
  await runCli([
    "run", "-d", "--id", arm.name, "--",
    process.execPath, child, arm.receivedPath,
  ]);
  return waitFor(
    `${arm.name} startup`,
    () => queryStats(arm.name),
    (stats) => stats.process.alive,
  );
}

async function restartArm(arm) {
  arm.publisher?.close();
  arm.publisher = null;
  await removeSession(arm.name);
  return spawnArm(arm);
}

async function ensurePublisher(arm) {
  if (arm.publisher !== null) return arm.publisher;
  arm.publisherOrdinal += 1;
  arm.publisher = await connectActivityPublisher(arm.name, {
    producerEpoch: `${arm.id}-epoch-${arm.publisherOrdinal}`,
    source: "generic-eval",
  });
  return arm.publisher;
}

async function setActivity(arm, state, caseId) {
  if (state === "unknown") {
    arm.publisher?.close();
    arm.publisher = null;
    await waitFor(
      `${arm.name} unknown`,
      () => queryStats(arm.name),
      (stats) => stats.activity.state === "unknown" && stats.activity.producerEpoch === null,
    );
    return;
  }
  const publisher = await ensurePublisher(arm);
  await publisher.publish(state, { turnId: caseId });
}

function enqueue(arm, messages) {
  arm.queue.push(...messages.map((message) => ({ ...message })));
}

function runHook(arm, available = true) {
  if (!available) return [];
  const delivered = arm.queue.splice(0);
  arm.archive.push(...delivered);
  return delivered;
}

async function aggressiveWake(arm, marker, unsafe) {
  arm.wakeAttempts += 1;
  const before = (await readBytes(arm.receivedPath)).length;
  await sendData({ name: arm.name, data: [marker] });
  const after = await waitForMarker(arm.receivedPath, marker);
  arm.ptyBytes += Buffer.byteLength(marker);
  assert.ok(after.length >= before + Buffer.byteLength(marker));
  if (unsafe) {
    arm.unsafeWrites += 1;
  }
  return { attempted: true, accepted: true, bytes: Buffer.byteLength(marker) };
}

async function guardedWake(arm, marker, { composerEmpty, dnd = false }) {
  if (dnd) return { attempted: false, accepted: false, reason: "dnd" };
  const observed = await queryStats(arm.name);
  if (observed.activity.state !== "idle") {
    return { attempted: false, accepted: false, reason: observed.activity.state };
  }
  if (!composerEmpty) {
    return { attempted: false, accepted: false, reason: "composer-nonempty" };
  }
  arm.wakeAttempts += 1;
  const before = (await readBytes(arm.receivedPath)).length;
  const response = await compareAndSend(arm.name, {
    generation: observed.generation,
    ioRevision: observed.ioRevision,
    data: marker,
  });
  if (!response.ok) {
    assert.equal((await readBytes(arm.receivedPath)).length, before);
    return { attempted: true, accepted: false, reason: response.error };
  }
  const after = await waitForMarker(arm.receivedPath, marker);
  arm.ptyBytes += Buffer.byteLength(marker);
  assert.ok(after.length >= before + Buffer.byteLength(marker));
  return { attempted: true, accepted: true, bytes: Buffer.byteLength(marker) };
}

function compareArchives(caseId, messages, startA, startB) {
  const deliveredA = armA.archive.slice(startA);
  const deliveredB = armB.archive.slice(startB);
  const expected = messages.map(({ id, sha256 }) => ({ id, sha256 }));
  assert.deepEqual(
    deliveredA.map(({ id, sha256 }) => ({ id, sha256 })),
    expected,
    `${caseId} arm A delivery`,
  );
  assert.deepEqual(
    deliveredB.map(({ id, sha256 }) => ({ id, sha256 })),
    expected,
    `${caseId} arm B delivery`,
  );
  assert.equal(new Set(deliveredA.map(({ id }) => id)).size, deliveredA.length);
  assert.equal(new Set(deliveredB.map(({ id }) => id)).size, deliveredB.length);
}

const receipt = {
  dependency: {
    activityHead: ACTIVITY_HEAD,
    guardedHead: GUARDED_HEAD,
    packageLockSha256: PACKAGE_LOCK_SHA256,
    cliSha256: await sha256(cli),
    clientSha256: await sha256(path.join(packageRoot, "dist", "client-api.js")),
    evidenceClass: "local-exact-source-build",
  },
  cases: [],
  summary: {},
  modelCalls: 0,
  cleanup: { sessions: null },
  boundary: {
    proven: "external-reference-adapter-at-pty-boundary",
    missing: "st2-configured-ding-adapter-and-provider-composer-hook-contract",
  },
};

try {
  await Promise.all(arms.map(spawnArm));

  for (const caseId of CASE_IDS) {
    const count = caseId === "fifo-burst" ? 3 : 1;
    const messages = Array.from({ length: count }, (_, ordinal) => durableMessage(caseId, ordinal));
    const startA = armA.archive.length;
    const startB = armB.archive.length;
    enqueue(armA, messages);
    enqueue(armB, messages);
    const caseReceipt = { caseId, messages, armA: {}, armB: {} };

    if (caseId === "crash-restart") {
      await Promise.all(arms.map(restartArm));
      caseReceipt.restarted = true;
    }

    const activity = (
      caseId === "idle" || caseId === "dnd" || caseId === "fifo-burst"
    ) ? "idle" : (
      caseId === "active-turn" || caseId === "hook-failure"
    ) ? "active" : caseId === "long-child" ? "child_command" : "unknown";
    await Promise.all(arms.map((arm) => setActivity(arm, activity, caseId)));

    if (caseId === "active-turn") {
      const draft = "PARTIAL-HUMAN-DRAFT-57";
      await Promise.all(arms.map(async (arm) => {
        await sendData({ name: arm.name, data: [draft] });
        await waitForMarker(arm.receivedPath, draft);
      }));
      caseReceipt.partialDraft = draft;
      const draftBytes = Buffer.from(draft);
      for (const arm of arms) {
        const beforeDelivery = await readBytes(arm.receivedPath);
        assert.ok(beforeDelivery.subarray(-draftBytes.length).equals(draftBytes),
          `${arm.id} partial draft was not live immediately before delivery`);
      }
      caseReceipt.partialDraftLiveBeforeDelivery = { armA: true, armB: true };
    }

    if (caseId === "dnd") {
      caseReceipt.armA.held = { attempted: false, reason: "dnd" };
      caseReceipt.armB.held = await guardedWake(armB, "B:dnd:held", {
        composerEmpty: true,
        dnd: true,
      });
      assert.equal(caseReceipt.armB.held.attempted, false);
      caseReceipt.armA.wake = await aggressiveWake(armA, "A:dnd:0", false);
      caseReceipt.armB.wake = await guardedWake(armB, "B:dnd:0", {
        composerEmpty: true,
      });
      runHook(armA);
      runHook(armB);
    } else if (caseId === "fifo-burst") {
      caseReceipt.armA.wakes = [];
      caseReceipt.armB.wakes = [];
      for (let ordinal = 0; ordinal < messages.length; ordinal += 1) {
        caseReceipt.armA.wakes.push(
          await aggressiveWake(armA, `A:fifo:${ordinal}`, false),
        );
        caseReceipt.armB.wakes.push(
          await guardedWake(armB, `B:fifo:${ordinal}`, { composerEmpty: true }),
        );
      }
      runHook(armA);
      runHook(armB);
    } else {
      const unsafe = activity !== "idle" || caseId === "active-turn";
      const markerA = `A:${caseId}:0`;
      const markerB = `B:${caseId}:0`;
      caseReceipt.armA.wake = await aggressiveWake(armA, markerA, unsafe);
      caseReceipt.armB.wake = await guardedWake(armB, markerB, {
        composerEmpty: caseId !== "active-turn",
      });
      if (caseId === "active-turn") {
        const draftBytes = Buffer.from(caseReceipt.partialDraft);
        const collisionBytes = Buffer.concat([draftBytes, Buffer.from(markerA)]);
        const afterA = await readBytes(armA.receivedPath);
        const afterB = await readBytes(armB.receivedPath);
        assert.ok(afterA.subarray(-collisionBytes.length).equals(collisionBytes),
          "arm A DING marker was not observed after the live partial draft");
        assert.ok(afterB.subarray(-draftBytes.length).equals(draftBytes),
          "arm B partial draft changed during guarded delivery");
        assert.equal(afterB.includes(markerB), false);
        caseReceipt.observedPartialDraftCollision = {
          armA: true,
          armB: false,
          observation: "DING PTY marker arrived after the live partial draft",
        };
      }

      if (caseId === "hook-failure") {
        assert.deepEqual(runHook(armA, false), []);
        assert.deepEqual(runHook(armB, false), []);
        assert.equal(armA.queue.length, 1);
        assert.equal(armB.queue.length, 1);
      }
      runHook(armA);
      runHook(armB);
    }

    compareArchives(caseId, messages, startA, startB);
    caseReceipt.armA.archive = armA.archive.slice(startA).map(({ id, sha256 }) => ({ id, sha256 }));
    caseReceipt.armB.archive = armB.archive.slice(startB).map(({ id, sha256 }) => ({ id, sha256 }));
    receipt.cases.push(caseReceipt);
  }

  assert.equal(armA.queue.length, 0);
  assert.equal(armB.queue.length, 0);
  assert.deepEqual(
    armA.archive.map(({ id, sha256 }) => ({ id, sha256 })),
    armB.archive.map(({ id, sha256 }) => ({ id, sha256 })),
  );

  const activeCase = receipt.cases.find(({ caseId }) => caseId === "active-turn");
  const idleCase = receipt.cases.find(({ caseId }) => caseId === "idle");
  assert.equal(activeCase.armA.wake.accepted, true);
  assert.equal(activeCase.armB.wake.accepted, false);
  assert.equal(activeCase.armB.wake.reason, "active");
  assert.equal(idleCase.armB.wake.attempted, true);
  assert.equal(idleCase.armB.wake.accepted, true);

  const observedPartialDraftCollisionsA = receipt.cases
    .filter((entry) => entry.observedPartialDraftCollision?.armA)
    .length;
  const observedPartialDraftCollisionsB = receipt.cases
    .filter((entry) => entry.observedPartialDraftCollision?.armB)
    .length;
  assert.deepEqual(activeCase.partialDraftLiveBeforeDelivery, { armA: true, armB: true });
  assert.deepEqual(activeCase.observedPartialDraftCollision, {
    armA: true,
    armB: false,
    observation: "DING PTY marker arrived after the live partial draft",
  });

  receipt.summary = {
    deliveryParity: true,
    deliveredMessages: armA.archive.length,
    armAPtyBytes: armA.ptyBytes,
    armBPtyBytes: armB.ptyBytes,
    armAUnsafeWrites: armA.unsafeWrites,
    armBUnsafeWrites: armB.unsafeWrites,
    armAObservedPartialDraftCollisions: observedPartialDraftCollisionsA,
    armBObservedPartialDraftCollisions: observedPartialDraftCollisionsB,
    armAWakeAttempts: armA.wakeAttempts,
    armBWakeAttempts: armB.wakeAttempts,
  };
  assert.equal(receipt.summary.armAUnsafeWrites, 6);
  assert.equal(receipt.summary.armBUnsafeWrites, 0);
  assert.equal(receipt.summary.armAObservedPartialDraftCollisions, 1);
  assert.equal(receipt.summary.armBObservedPartialDraftCollisions, 0);
} finally {
  for (const arm of arms) {
    arm.publisher?.close();
    arm.publisher = null;
  }
  await Promise.all(arms.map((arm) => removeSession(arm.name)));
}

receipt.cleanup.sessions = (await listSessions()).length;
assert.equal(receipt.cleanup.sessions, 0);
await writeFile(
  path.join(catalog, "delivery-ab-receipt.json"),
  `${JSON.stringify(receipt, null, 2)}\n`,
);

console.log("DING-AB-EXACT-PTY-HEADS-GREEN-57b1");
console.log("DING-AB-DURABILITY-PARITY-GREEN-57b1");
console.log("DING-AB-ACTIVE-TURN-IMPROVEMENT-GREEN-57b1");
console.log("DING-AB-IDLE-BOUNDED-WAKE-GREEN-57b1");
console.log("DING-AB-HOLD-RECOVERY-GREEN-57b1");
console.log("DING-AB-FIFO-GREEN-57b1");
console.log("DING-AB-IMPROVEMENT-GREEN-57b1");
console.log("DING-AB-CLEANUP-MODEL-FREE-GREEN-57b1");
