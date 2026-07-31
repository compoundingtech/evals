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
const CANDIDATE = "DING-CANDIDATE-57";

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
const ptyRoot = path.join(catalog, "pty-pr133-guarded");
const cli = path.join(packageRoot, "bin", "pty");
const child = path.join(catalog, "guard-child.mjs");
const receivedPath = path.join(catalog, "received.bin");
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
  MAX_GUARDED_DATA_BYTES,
  SessionConnection,
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

async function spawnSession(name) {
  await runCli(["run", "-d", "--id", name, "--", process.execPath, child, receivedPath]);
  return waitFor(
    `${name} startup`,
    () => queryStats(name),
    (stats) => stats.process.alive && stats.process.pid !== null,
  );
}

async function stableStats(name) {
  let previous = await queryStats(name);
  for (let attempt = 0; attempt < 80; attempt += 1) {
    await sleep(25);
    const current = await queryStats(name);
    if (current.ioRevision === previous.ioRevision) return current;
    previous = current;
  }
  throw new Error("PTY I/O revision did not settle");
}

async function received() {
  try {
    return await readFile(receivedPath);
  } catch (error) {
    if (error.code === "ENOENT") return Buffer.alloc(0);
    throw error;
  }
}

async function waitForReceivedLength(minimum) {
  return waitFor(
    `received-byte length >= ${minimum}`,
    received,
    (buffer) => buffer.length >= minimum,
  );
}

function assertCandidateAbsent(buffer) {
  assert.equal(buffer.includes(Buffer.from(CANDIDATE)), false);
}

const name = "ding-guarded-send";
const receipt = {
  dependency: {
    activityHead: ACTIVITY_HEAD,
    guardedHead: GUARDED_HEAD,
    packageLockSha256: PACKAGE_LOCK_SHA256,
    cliSha256: await sha256(cli),
    clientSha256: await sha256(path.join(packageRoot, "dist", "client-api.js")),
    evidenceClass: "local-exact-source-build",
  },
  cases: {
    inputRaces: [],
    revisionRaces: [],
    invalid: [],
  },
  modelCalls: 0,
  cleanup: { sessions: null },
};

try {
  const initial = await spawnSession(name);
  const quiet = await stableStats(name);
  assert.equal(quiet.generation, initial.generation);

  const beforeSuccess = (await received()).length;
  const exact = await compareAndSend(name, {
    generation: quiet.generation,
    ioRevision: quiet.ioRevision,
    data: "Q",
  });
  assert.equal(exact.ok, true);
  await waitForReceivedLength(beforeSuccess + 1);
  const afterSuccess = await received();
  assert.equal(afterSuccess.subarray(beforeSuccess).toString("utf8"), "Q");

  const replay = await compareAndSend(name, {
    generation: quiet.generation,
    ioRevision: quiet.ioRevision,
    data: CANDIDATE,
  });
  assert.equal(replay.ok, false);
  await sleep(50);
  assertCandidateAbsent(await received());
  receipt.cases.exactlyOnce = { exact, replay };

  const inputCases = [
    ["recent-key", { data: ["k"] }],
    ["newline", { data: ["\r"] }],
    ["paste", { data: ["PASTE-57"], paste: true }],
    ["escape", { data: ["\u001b"] }],
    ["supervisor-input", { data: ["s"] }],
  ];
  for (const [caseId, options] of inputCases) {
    const token = await stableStats(name);
    const before = (await received()).length;
    await sendData({ name, ...options });
    const afterInput = await waitForReceivedLength(before + 1);
    const response = await compareAndSend(name, {
      generation: token.generation,
      ioRevision: token.ioRevision,
      data: CANDIDATE,
    });
    assert.equal(response.ok, false, caseId);
    await sleep(30);
    const afterCandidate = await received();
    assert.equal(afterCandidate.length, afterInput.length, caseId);
    assertCandidateAbsent(afterCandidate);
    receipt.cases.inputRaces.push({
      caseId,
      beforeRevision: token.ioRevision,
      response,
    });
  }

  const outputToken = await stableStats(name);
  process.kill(outputToken.process.pid, "SIGUSR1");
  await waitFor(
    "child output revision",
    () => queryStats(name),
    (stats) => stats.ioRevision > outputToken.ioRevision,
  );
  const outputBytes = (await received()).length;
  const outputRace = await compareAndSend(name, {
    generation: outputToken.generation,
    ioRevision: outputToken.ioRevision,
    data: CANDIDATE,
  });
  assert.equal(outputRace.ok, false);
  assert.equal((await received()).length, outputBytes);
  assertCandidateAbsent(await received());
  receipt.cases.revisionRaces.push({ caseId: "output", response: outputRace });

  const viewer = new SessionConnection({
    name,
    rows: (await queryStats(name)).terminal.rows,
    cols: (await queryStats(name)).terminal.cols,
  });
  await viewer.connect();
  const viewerToken = await stableStats(name);
  await sleep(50);
  assert.equal((await queryStats(name)).ioRevision, viewerToken.ioRevision);
  const viewerBefore = (await received()).length;
  const viewerSend = await compareAndSend(name, {
    generation: viewerToken.generation,
    ioRevision: viewerToken.ioRevision,
    data: "V",
  });
  assert.equal(viewerSend.ok, true);
  await waitForReceivedLength(viewerBefore + 1);
  receipt.cases.viewerNoIo = viewerSend;
  viewer.disconnect();

  const resizeViewer = new SessionConnection({
    name,
    rows: (await queryStats(name)).terminal.rows,
    cols: (await queryStats(name)).terminal.cols,
  });
  await resizeViewer.connect();
  const resizeToken = await stableStats(name);
  resizeViewer.resize(resizeToken.terminal.rows + 1, resizeToken.terminal.cols + 1);
  await waitFor(
    "resize revision",
    () => queryStats(name),
    (stats) => stats.ioRevision > resizeToken.ioRevision,
  );
  const resizeBytes = (await received()).length;
  const resizeRace = await compareAndSend(name, {
    generation: resizeToken.generation,
    ioRevision: resizeToken.ioRevision,
    data: CANDIDATE,
  });
  assert.equal(resizeRace.ok, false);
  assert.equal((await received()).length, resizeBytes);
  assertCandidateAbsent(await received());
  receipt.cases.revisionRaces.push({ caseId: "resize", response: resizeRace });
  resizeViewer.disconnect();

  const activity = await connectActivityPublisher(name, {
    producerEpoch: "guarded-send-epoch",
    source: "generic-eval",
  });
  await activity.publish("idle", { turnId: "turn-57" });
  const activityToken = await stableStats(name);
  await activity.publish("active", { turnId: "turn-57" });
  const activityBytes = (await received()).length;
  const activityRace = await compareAndSend(name, {
    generation: activityToken.generation,
    ioRevision: activityToken.ioRevision,
    data: CANDIDATE,
  });
  assert.equal(activityRace.ok, false);
  assert.equal((await received()).length, activityBytes);
  assertCandidateAbsent(await received());
  receipt.cases.revisionRaces.push({ caseId: "activity", response: activityRace });
  activity.close();

  const invalidToken = await stableStats(name);
  for (const [caseId, options] of [
    ["wrong-generation", {
      generation: "wrong-generation",
      ioRevision: invalidToken.ioRevision,
      data: CANDIDATE,
    }],
    ["empty", {
      generation: invalidToken.generation,
      ioRevision: invalidToken.ioRevision,
      data: "",
    }],
    ["oversize", {
      generation: invalidToken.generation,
      ioRevision: invalidToken.ioRevision,
      data: "x".repeat(MAX_GUARDED_DATA_BYTES + 1),
    }],
  ]) {
    const before = (await received()).length;
    const response = await compareAndSend(name, options);
    assert.equal(response.ok, false, caseId);
    assert.equal((await received()).length, before, caseId);
    assertCandidateAbsent(await received());
    receipt.cases.invalid.push({ caseId, response });
  }

  const oldToken = await stableStats(name);
  await removeSession(name);
  const restarted = await spawnSession(name);
  assert.notEqual(restarted.generation, oldToken.generation);
  const restartBytes = (await received()).length;
  const restartRace = await compareAndSend(name, {
    generation: oldToken.generation,
    ioRevision: oldToken.ioRevision,
    data: CANDIDATE,
  });
  assert.equal(restartRace.ok, false);
  assert.equal((await received()).length, restartBytes);
  assertCandidateAbsent(await received());
  receipt.cases.restart = {
    before: oldToken.generation,
    after: restarted.generation,
    response: restartRace,
  };
} finally {
  await removeSession(name);
}

receipt.cleanup.sessions = (await listSessions()).length;
assert.equal(receipt.cleanup.sessions, 0);
await writeFile(
  path.join(catalog, "guarded-send-receipt.json"),
  `${JSON.stringify(receipt, null, 2)}\n`,
);

console.log("PTY-PR133-EXACT-HEAD-GREEN-57g1");
console.log("GUARDED-SEND-EXACTLY-ONCE-GREEN-57g1");
console.log("GUARDED-SEND-INPUT-RACES-GREEN-57g1");
console.log("GUARDED-SEND-REVISION-RACES-GREEN-57g1");
console.log("GUARDED-SEND-VIEWER-NO-IO-GREEN-57g1");
console.log("GUARDED-SEND-RESTART-GREEN-57g1");
console.log("GUARDED-SEND-INVALID-ZERO-BYTES-GREEN-57g1");
console.log("GUARDED-SEND-CLEANUP-MODEL-FREE-GREEN-57g1");
