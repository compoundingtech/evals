import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import {
  mkdir,
  readFile,
  readdir,
  readlink,
  realpath,
  rename,
  stat,
  writeFile,
} from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const ST2_HEAD = "d7500b0fcad8bb268da9da96c0226d9caddbe305";
const ST2_CARGO_LOCK_SHA256 = "56d7956f328d7525eea04c70f5767acb3bc207c9509e7e2cc332444a4ede2f3e";
const ST2_BINARY_SHA256 = "705ad3ebd0bce497a4117c7c7993505c0579fc1f7df2421e0525a22208f6949f";
const PTY_ACTIVITY_HEAD = "46c71d31c0d6daee43adf568061b2b84a65ae8c0";
const PTY_GUARDED_HEAD = "743ceb796a41a3282e31382575bff0d0e3826d59";
const PTY_PACKAGE_LOCK_SHA256 = "43189b5b5b1d560be4b9102d2ed0793d89b9b01dbb3bbd976948f10c6669118d";
const PTY_CLI_SHA256 = "60e90a8a0041845c0e382e2cf3873c005bed2a95db8991697e0449c3a71a558d";
const PTY_CLIENT_SHA256 = "b3026b70ea0aff6ab6a07c4371ce11cd3f600c75ac9584e653fe702212658bae";
const CASES = [
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
const UNSAFE_CASES = new Set([
  "active-turn",
  "long-child",
  "stale-unknown",
  "hook-failure",
  "crash-restart",
  "compaction-clear",
]);
const TOTAL_MESSAGES = 11;

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

async function waitFor(label, operation, predicate, attempts = 400, pause = 25) {
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const value = await operation();
      if (predicate(value)) return value;
    } catch (error) {
      lastError = error;
    }
    await sleep(pause);
  }
  throw new Error(`timed out waiting for ${label}${lastError ? `: ${lastError.message}` : ""}`);
}

async function exists(file) {
  try {
    await stat(file);
    return true;
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
}

async function readBytes(file) {
  try {
    return await readFile(file);
  } catch (error) {
    if (error.code === "ENOENT") return Buffer.alloc(0);
    throw error;
  }
}

function occurrences(buffer, text) {
  const haystack = buffer.toString("utf8");
  let count = 0;
  let offset = 0;
  while ((offset = haystack.indexOf(text, offset)) >= 0) {
    count += 1;
    offset += text.length;
  }
  return count;
}

function kdl(value) {
  return JSON.stringify(value);
}

const st2Root = requiredEnv("EVALS_ST2_PR123_ROOT");
const ptyPackageRoot = requiredEnv("EVALS_PTY_PR133_ROOT");
const catalog = requiredEnv("CATALOG");
const st2Bin = path.join(st2Root, "target", "release", "st2");
const ptyCli = path.join(ptyPackageRoot, "bin", "pty");
const st2BinDir = path.dirname(st2Bin);
const ptyBinDir = path.dirname(ptyCli);
const net = path.join(catalog, "integrated-net");
const ptyRoot = path.join(catalog, "i57pty");
const stateRoot = path.join(catalog, "integrated-state");
const execState = path.join(stateRoot, "st2", "matrix", "exec");
const controlPath = path.join(net, "activity-control.json");
const proofPath = path.join(net, "adapter-launch.jsonl");
const tracePath = path.join(net, "adapter-trace.jsonl");
const aBytesPath = path.join(net, "received-a.bin");
const bBytesPath = path.join(net, "received-b.bin");
const runtimePath = [st2BinDir, ptyBinDir, process.env.PATH].join(":");
const runtimeEnv = {
  ...process.env,
  PATH: runtimePath,
  PTY_ROOT: ptyRoot,
  XDG_STATE_HOME: stateRoot,
};
process.env.PTY_ROOT = ptyRoot;

async function run(program, args, options = {}) {
  return execFileAsync(program, args, {
    env: runtimeEnv,
    cwd: catalog,
    maxBuffer: 4 * 1024 * 1024,
    ...options,
  });
}

async function runSt2(args) {
  return run(st2Bin, args);
}

async function runPty(args) {
  return run(ptyCli, args);
}

async function git(args, root) {
  return run("git", ["-C", root, ...args]);
}

assert.equal((await git(["rev-parse", "HEAD"], st2Root)).stdout.trim(), ST2_HEAD);
assert.equal((await git(["status", "--porcelain"], st2Root)).stdout, "");
assert.equal(await sha256(path.join(st2Root, "Cargo.lock")), ST2_CARGO_LOCK_SHA256);
assert.equal(await sha256(st2Bin), ST2_BINARY_SHA256);
const st2Version = (await runSt2(["--version"])).stdout.trim();
assert.match(st2Version, /^st2 0\.1\.0 — running from local source \(d7500b0, .+ ago\)$/);

assert.equal((await git(["rev-parse", "HEAD"], ptyPackageRoot)).stdout.trim(), PTY_GUARDED_HEAD);
await git(["merge-base", "--is-ancestor", PTY_ACTIVITY_HEAD, PTY_GUARDED_HEAD], ptyPackageRoot);
assert.equal((await git(["status", "--porcelain"], ptyPackageRoot)).stdout, "");
assert.equal(await sha256(path.join(ptyPackageRoot, "package-lock.json")), PTY_PACKAGE_LOCK_SHA256);
assert.equal(await sha256(ptyCli), PTY_CLI_SHA256);
assert.equal(
  await sha256(path.join(ptyPackageRoot, "dist", "client-api.js")),
  PTY_CLIENT_SHA256,
);

const ptyClient = await import(
  pathToFileURL(path.join(ptyPackageRoot, "dist", "client-api.js"))
);
const { connectActivityPublisher, queryStats, sendData } = ptyClient;

await mkdir(path.join(net, "agents", "matrix", "a"), { recursive: true });
await mkdir(path.join(net, "agents", "matrix", "b"), { recursive: true });

function agentDeclaration(identity, rich) {
  const received = identity === "a" ? aBytesPath : bBytesPath;
  const env = {
    PATH: runtimePath,
    ST_AGENT: `matrix.${identity}`,
    NODE_BIN: process.execPath,
    FIXTURE_ROOT: catalog,
    ADAPTER_ROOT: catalog,
    ADAPTER_CONTROL: controlPath,
    ADAPTER_PROOF: proofPath,
    ADAPTER_TRACE: tracePath,
    PTY_PACKAGE_ROOT: ptyPackageRoot,
  };
  const envLines = Object.entries(env)
    .map(([key, value]) => `    ${key} ${kdl(value)}`)
    .join("\n");
  const ding = rich
    ? `ding {
    adapter {
      argv "$NODE_BIN" "$ADAPTER_ROOT/activity-adapter.mjs" "--control" "$ADAPTER_CONTROL" "--proof" "$ADAPTER_PROOF" "--trace" "$ADAPTER_TRACE" "space arg" "; touch forbidden"
    }
  }`
    : "ding";
  return `agent ${kdl(identity)} {
  host "matrix"
  workspace "$CATALOG"
  env {
${envLines}
  }
  argv "$NODE_BIN" "$FIXTURE_ROOT/ab-child.mjs" ${kdl(received)}
  ${ding}
}
`;
}

await writeFile(
  path.join(net, "agents", "matrix", "a", "agent.kdl"),
  agentDeclaration("a", false),
);
await writeFile(
  path.join(net, "agents", "matrix", "b", "agent.kdl"),
  agentDeclaration("b", true),
);

await runSt2(["validate", "--catalog", net, "--host", "matrix", "--strict"]);

function execPidPath(id) {
  return path.join(execState, `${id}.pid`);
}

async function readPid(id) {
  return Number.parseInt((await readFile(execPidPath(id), "utf8")).trim(), 10);
}

async function pidAlive(pid) {
  if (!Number.isSafeInteger(pid) || pid <= 1) return false;
  try {
    process.kill(pid, 0);
    const fields = (await readFile(`/proc/${pid}/stat`, "utf8")).split(" ");
    return fields[2] !== "Z";
  } catch (error) {
    if (error.code === "ESRCH" || error.code === "ENOENT") return false;
    throw error;
  }
}

async function processIdentityAlive(identity) {
  try {
    const raw = await readFile(`/proc/${identity.pid}/stat`, "utf8");
    const close = raw.lastIndexOf(")");
    const fields = raw.slice(close + 2).split(" ");
    if (fields[0] === "Z" || fields[19] !== identity.processStart) return false;
    return await realpath(await readlink(`/proc/${identity.pid}/exe`)) === identity.executable;
  } catch (error) {
    if (error.code === "ENOENT" || error.code === "ESRCH") return false;
    throw error;
  }
}

async function processGroupMembers(leaderPid) {
  const members = [];
  for (const name of await readdir("/proc")) {
    if (!/^[0-9]+$/.test(name)) continue;
    const pid = Number.parseInt(name, 10);
    try {
      const raw = await readFile(`/proc/${pid}/stat`, "utf8");
      const close = raw.lastIndexOf(")");
      const fields = raw.slice(close + 2).split(" ");
      const processGroup = Number.parseInt(fields[2], 10);
      if (processGroup !== leaderPid || fields[0] === "Z") continue;
      members.push({
        pid,
        processStart: fields[19],
        executable: await realpath(await readlink(`/proc/${pid}/exe`)),
      });
    } catch (error) {
      if (error.code !== "ENOENT" && error.code !== "ESRCH") throw error;
    }
  }
  members.sort((left, right) => left.pid - right.pid);
  return members;
}

async function listSessions() {
  const { stdout } = await runPty(["list", "--json"]);
  return JSON.parse(stdout);
}

async function waitForSession(name) {
  return waitFor(
    `${name} running`,
    () => listSessions(),
    (sessions) => sessions.some((session) => session.name === name && session.status === "running"),
  );
}

function sidecarLog(id) {
  return path.join(net, "logs", `${id}.ding.log`);
}

async function waitForLog(id, marker, start = 0) {
  return waitFor(
    `${id} log marker ${marker}`,
    async () => (await readFile(sidecarLog(id), "utf8")).slice(start),
    (text) => text.includes(marker),
  );
}

async function jsonLines(file) {
  try {
    return (await readFile(file, "utf8"))
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

const sidecarExecutables = [];
async function recordSidecarExecutable(id) {
  const pid = await readPid(`${id}.ding`);
  const exactSt2 = await realpath(st2Bin);
  const members = await waitFor(
    `${id} exact st2 process-group member`,
    () => processGroupMembers(pid),
    (entries) => entries.some((entry) => entry.executable === exactSt2),
  );
  sidecarExecutables.push({ id, groupLeader: pid, members });
}

let expectedAdapterLaunches = 0;
async function startTeam() {
  expectedAdapterLaunches += 1;
  await runSt2(["up", "--catalog", net, "--host", "matrix", "--once"]);
  await Promise.all([waitForSession("matrix.a"), waitForSession("matrix.b")]);
  await waitForLog("matrix.a", "ready — found 0 existing unread message(s)");
  await waitForLog("matrix.b", "rich adapter ready — found 0 existing unread message(s)");
  await waitFor(
    `${expectedAdapterLaunches} adapter launch proofs`,
    () => jsonLines(proofPath),
    (lines) => lines.length >= expectedAdapterLaunches,
  );
  await recordSidecarExecutable("matrix.a");
  await recordSidecarExecutable("matrix.b");
}

async function setStatus(identity, state) {
  await runSt2([
    "status",
    identity,
    "--set",
    state,
    "--catalog",
    net,
    "--host",
    "matrix",
    "--as",
    identity,
  ]);
}

async function writeControl(command) {
  const temporary = `${controlPath}.tmp`;
  await writeFile(temporary, `${JSON.stringify(command)}\n`);
  await rename(temporary, controlPath);
  return waitFor(
    `adapter trace ${command.id}`,
    () => jsonLines(tracePath),
    (lines) => lines.find((line) => line.id === command.id),
  );
}

let aPublisher = null;
let aPublisherOrdinal = 0;
async function ensureAPublisher() {
  if (aPublisher) return aPublisher;
  aPublisherOrdinal += 1;
  aPublisher = await connectActivityPublisher("matrix.a", {
    producerEpoch: `aggressive-a-${aPublisherOrdinal}`,
    source: "generic-evals-57-control",
  });
  return aPublisher;
}

async function setAActivity(state, id) {
  if (state === "unknown") {
    aPublisher?.close();
    aPublisher = null;
    await waitFor(
      `matrix.a unknown activity for ${id}`,
      () => queryStats("matrix.a"),
      (stats) => stats.activity.state === "unknown" && stats.activity.producerEpoch === null,
    );
    return;
  }
  const publisher = await ensureAPublisher();
  await publisher.publish(state, { turnId: id });
  await waitFor(
    `matrix.a ${state} activity for ${id}`,
    () => queryStats("matrix.a"),
    (stats) => stats.activity.state === state,
  );
}

function activityFor(caseId) {
  if (caseId === "idle" || caseId === "dnd" || caseId === "fifo-burst") return "idle";
  if (caseId === "active-turn" || caseId === "hook-failure") return "active";
  if (caseId === "long-child") return "child_command";
  return "unknown";
}

function richCommand(caseId, ordinal) {
  const id = `${caseId}-${ordinal}-${Date.now()}`;
  if (caseId === "stale-unknown") {
    return { id, state: "idle", inputBuffer: "empty", validForMs: 25 };
  }
  const activity = activityFor(caseId);
  return {
    id,
    state: activity === "child_command" ? "child" : activity,
    inputBuffer: caseId === "active-turn" ? "nonempty" : activity === "unknown" ? "unknown" : "empty",
    validForMs: 1800,
  };
}

async function sendMessage(identity, subject, body) {
  const { stdout } = await runSt2([
    "message",
    "send",
    identity,
    "--catalog",
    net,
    "--host",
    "matrix",
    "--as",
    "matrix.sender",
    "--subject",
    subject,
    "-m",
    body,
  ]);
  const filename = stdout.trim();
  assert.match(filename, /^[0-9]{13}-[0-9a-z]{6}\.md$/);
  return filename;
}

async function readAndArchive(identity, filename, expected) {
  const { stdout } = await runSt2([
    "message",
    "read",
    identity,
    filename,
    "--json",
    "--catalog",
    net,
    "--host",
    "matrix",
    "--as",
    identity,
  ]);
  const message = JSON.parse(stdout);
  assert.equal(message.filename, filename);
  assert.equal(message.subject, expected.subject);
  assert.equal(message.body, expected.body);
  assert.equal(digest(message.body), expected.sha256);
  await runSt2([
    "message",
    "archive",
    identity,
    filename,
    "--catalog",
    net,
    "--host",
    "matrix",
    "--as",
    identity,
  ]);
  return { id: expected.id, sha256: expected.sha256, filename };
}

async function hookOwn(filename) {
  await runSt2([
    "ding-control",
    "--identity",
    "matrix.b",
    "--catalog",
    net,
    "--host",
    "matrix",
    "hook-owned",
    "--message",
    filename,
  ]);
}

async function waitForNoOwnership(filename) {
  const directory = path.join(net, "agents", "matrix", "b", "resources", "ding-control");
  await waitFor(
    `ownership cleanup for ${filename}`,
    async () => {
      try {
        return await Promise.all(
          (await readdir(directory)).map(async (name) => ({
            name,
            text: await readFile(path.join(directory, name), "utf8"),
          })),
        );
      } catch (error) {
        if (error.code === "ENOENT") return [];
        throw error;
      }
    },
    (records) => records.every((record) => !record.text.includes(filename)),
  );
}

async function inboxCount(identity) {
  const { stdout } = await runSt2([
    "message",
    "ls",
    identity,
    "--count",
    "--catalog",
    net,
    "--host",
    "matrix",
    "--as",
    identity,
  ]);
  return Number.parseInt(stdout.trim(), 10);
}

async function waitForExecTasksDead() {
  for (const id of ["matrix.a.ding", "matrix.b.ding"]) {
    if (!(await exists(execPidPath(id)))) continue;
    const pid = await readPid(id);
    await waitFor(`${id} stopped`, () => pidAlive(pid), (alive) => !alive);
  }
}

async function waitForTrackedProcessesDead() {
  const identities = sidecarExecutables.flatMap((launch) => launch.members);
  await waitFor(
    "all tracked sidecar process identities stopped",
    async () => Promise.all(identities.map((identity) => processIdentityAlive(identity))),
    (alive) => alive.every((value) => !value),
  );
}

async function fullRestart() {
  aPublisher?.close();
  aPublisher = null;
  await runSt2(["down", "--catalog", net, "--host", "matrix"]);
  await waitForExecTasksDead();
  await waitForTrackedProcessesDead();
  await waitFor(
    "matrix PTYs stopped",
    () => listSessions(),
    (sessions) => sessions.every((session) => session.status !== "running"),
  );
  await startTeam();
  await Promise.all([setStatus("matrix.a", "available"), setStatus("matrix.b", "available")]);
}

async function removeAllSessions() {
  for (let attempt = 0; attempt < 160; attempt += 1) {
    const sessions = await listSessions();
    if (sessions.length === 0) return;
    for (const session of sessions) {
      if (session.status === "running") {
        await runPty(["kill", session.name]).catch(() => {});
      } else {
        await runPty(["rm", session.name]).catch(() => {});
      }
    }
    await sleep(25);
  }
  throw new Error("integrated PTY sessions did not clean up");
}

const receipt = {
  dependency: {
    st2: {
      head: ST2_HEAD,
      cargoLockSha256: ST2_CARGO_LOCK_SHA256,
      binarySha256: ST2_BINARY_SHA256,
      version: st2Version,
      evidenceClass: "local-exact-source-release-build",
    },
    pty: {
      activityHead: PTY_ACTIVITY_HEAD,
      guardedHead: PTY_GUARDED_HEAD,
      packageLockSha256: PTY_PACKAGE_LOCK_SHA256,
      cliSha256: PTY_CLI_SHA256,
      clientSha256: PTY_CLIENT_SHA256,
      evidenceClass: "local-exact-source-build",
    },
  },
  taskEnvironment: {},
  cases: [],
  summary: {},
  modelCalls: 0,
  cleanup: { sessions: null, execProcesses: null },
  boundary: {
    proven: "integrated-st2-configured-generic-adapter-plus-hook-ownership",
    missing: "immutable-real-provider-activity-and-hook-fixtures-live-pane-acceptance-and-release-artifacts",
  },
};
const deliveredA = [];
const deliveredB = [];
const cleanupErrors = [];
let processedMessages = 0;

try {
  await startTeam();
  await Promise.all([setStatus("matrix.a", "available"), setStatus("matrix.b", "available")]);

  for (const caseId of CASES) {
    if (caseId === "crash-restart") await fullRestart();
    const count = caseId === "fifo-burst" ? 3 : 1;
    const caseReceipt = {
      caseId,
      messages: [],
      armA: { mode: "generated-unconfigured-aggressive", ptyWrites: 0, unsafeWrites: 0 },
      armB: { mode: "generated-configured-rich", ptyWrites: 0, hookOwned: 0 },
    };
    if (caseId === "crash-restart") caseReceipt.restartedBeforeDelivery = true;

    if (caseId === "fifo-burst") {
      await setAActivity("idle", caseId);
      await writeControl(richCommand(caseId, 0));
      const beforeA = await readBytes(aBytesPath);
      const beforeB = await readBytes(bBytesPath);
      let bLogStart = (await readFile(sidecarLog("matrix.b"), "utf8")).length;
      const records = [];
      for (let ordinal = 0; ordinal < count; ordinal += 1) {
        const id = `${caseId}-${ordinal}`;
        const subject = `st2-rich-ab-${caseId}-${ordinal}`;
        const body = `case=${caseId}\nordinal=${ordinal}\npayload=durable-st2-rich-ding-57\n`;
        const message = { id, subject, body, sha256: digest(body) };
        const filenameA = await sendMessage("matrix.a", subject, body);
        const filenameB = await sendMessage("matrix.b", subject, body);
        records.push({ message, filenameA, filenameB });
        await sleep(5);
      }

      await waitFor(
        "aggressive FIFO burst",
        () => readBytes(aBytesPath),
        (bytes) => records.every(({ message }) =>
          occurrences(bytes, message.subject) === occurrences(beforeA, message.subject) + 1),
      );
      for (let ordinal = 0; ordinal < records.length; ordinal += 1) {
        const record = records[ordinal];
        if (ordinal > 0) {
          bLogStart = (await readFile(sidecarLog("matrix.b"), "utf8")).length;
          await writeControl(richCommand(caseId, ordinal));
        }
        await waitFor(
          `guarded FIFO marker ${record.message.subject}`,
          () => readBytes(bBytesPath),
          (bytes) => occurrences(bytes, record.message.subject) ===
            occurrences(beforeB, record.message.subject) + 1,
        );
        await waitForLog("matrix.b", '"result":"pty-owned"', bLogStart);
        const archivedB = await readAndArchive(
          "matrix.b",
          record.filenameB,
          record.message,
        );
        deliveredB.push(archivedB);
        await waitForNoOwnership(record.filenameB);
      }

      await sleep(1100);
      const afterA = await readBytes(aBytesPath);
      const afterB = await readBytes(bBytesPath);
      const deltaA = afterA.subarray(beforeA.length).toString("utf8");
      const deltaB = afterB.subarray(beforeB.length).toString("utf8");
      let previousA = -1;
      let previousB = -1;
      for (const record of records) {
        const indexA = deltaA.indexOf(record.message.subject);
        const indexB = deltaB.indexOf(record.message.subject);
        assert.ok(indexA > previousA, "aggressive FIFO order changed");
        assert.ok(indexB > previousB, "configured FIFO order changed");
        previousA = indexA;
        previousB = indexB;
        assert.equal(
          occurrences(afterA, record.message.subject) - occurrences(beforeA, record.message.subject),
          1,
        );
        assert.equal(
          occurrences(afterB, record.message.subject) - occurrences(beforeB, record.message.subject),
          1,
        );
        const archivedA = await readAndArchive(
          "matrix.a",
          record.filenameA,
          record.message,
        );
        deliveredA.push(archivedA);
        caseReceipt.messages.push({
          id: record.message.id,
          sha256: record.message.sha256,
          filenameA: record.filenameA,
          filenameB: record.filenameB,
        });
      }
      caseReceipt.armA.ptyWrites = records.length;
      caseReceipt.armB.ptyWrites = records.length;
      caseReceipt.burstQueuedBeforeArchive = true;
      processedMessages += records.length;
      receipt.cases.push(caseReceipt);
      continue;
    }

    for (let ordinal = 0; ordinal < count; ordinal += 1) {
      const id = `${caseId}-${ordinal}`;
      const subject = `st2-rich-ab-${caseId}-${ordinal}`;
      const body = `case=${caseId}\nordinal=${ordinal}\npayload=durable-st2-rich-ding-57\n`;
      const message = { id, subject, body, sha256: digest(body) };

      if (caseId === "active-turn") {
        const draft = "PARTIAL-HUMAN-DRAFT-ST2-57";
        await Promise.all([
          sendData({ name: "matrix.a", data: [draft] }),
          sendData({ name: "matrix.b", data: [draft] }),
        ]);
        await Promise.all([
          waitFor("arm A partial draft", () => readBytes(aBytesPath), (bytes) => occurrences(bytes, draft) === 1),
          waitFor("arm B partial draft", () => readBytes(bBytesPath), (bytes) => occurrences(bytes, draft) === 1),
        ]);
        caseReceipt.partialDraft = draft;
      }

      await setAActivity(activityFor(caseId), id);
      const command = richCommand(caseId, ordinal);
      await writeControl(command);
      if (caseId === "stale-unknown") await sleep(100);

      if (caseId === "dnd") {
        await Promise.all([setStatus("matrix.a", "dnd"), setStatus("matrix.b", "dnd")]);
      }

      const beforeA = await readBytes(aBytesPath);
      const beforeB = await readBytes(bBytesPath);
      if (caseId === "active-turn") {
        const draftBytes = Buffer.from(caseReceipt.partialDraft);
        assert.ok(beforeA.subarray(-draftBytes.length).equals(draftBytes),
          "arm A partial draft was not live immediately before delivery");
        assert.ok(beforeB.subarray(-draftBytes.length).equals(draftBytes),
          "arm B partial draft was not live immediately before delivery");
        caseReceipt.partialDraftLiveBeforeDelivery = { armA: true, armB: true };
      }
      const bLogStart = (await readFile(sidecarLog("matrix.b"), "utf8")).length;
      const filenameA = await sendMessage("matrix.a", subject, body);
      const filenameB = await sendMessage("matrix.b", subject, body);

      if (caseId === "dnd") {
        await waitForLog("matrix.b", '"reason":"presence-dnd"', bLogStart);
        await sleep(250);
        assert.equal(occurrences(await readBytes(aBytesPath), subject), occurrences(beforeA, subject));
        assert.equal(occurrences(await readBytes(bBytesPath), subject), occurrences(beforeB, subject));
        caseReceipt.dndHeldZeroBytes = true;
        await Promise.all([setStatus("matrix.a", "available"), setStatus("matrix.b", "available")]);
        await writeControl({
          ...command,
          id: `${command.id}-released`,
          validForMs: 1800,
        });
      }

      await waitFor(
        `aggressive marker ${subject}`,
        () => readBytes(aBytesPath),
        (bytes) => occurrences(bytes, subject) === occurrences(beforeA, subject) + 1,
      );

      if (UNSAFE_CASES.has(caseId)) {
        const holdReason = caseId === "long-child"
          ? "activity-child"
          : caseId === "stale-unknown"
            ? "activity-stale"
            : caseId === "active-turn" || caseId === "hook-failure"
              ? "activity-active"
              : "activity-unknown";
        await waitForLog("matrix.b", `"reason":"${holdReason}"`, bLogStart);
        if (caseId === "hook-failure") {
          await sleep(300);
          assert.equal(await inboxCount("matrix.b"), 1);
          assert.equal(occurrences(await readBytes(bBytesPath), subject), occurrences(beforeB, subject));
          caseReceipt.hookFailureHeldUnread = true;
        }
        await hookOwn(filenameB);
        await waitForLog("matrix.b", filenameB, bLogStart);
        assert.equal(occurrences(await readBytes(bBytesPath), subject), occurrences(beforeB, subject));
        caseReceipt.armB.hookOwned += 1;
      } else {
        await waitFor(
          `guarded marker ${subject}`,
          () => readBytes(bBytesPath),
          (bytes) => occurrences(bytes, subject) === occurrences(beforeB, subject) + 1,
        );
        await waitForLog("matrix.b", '"result":"pty-owned"', bLogStart);
        caseReceipt.armB.ptyWrites += 1;
      }

      await sleep(1100);
      const afterA = await readBytes(aBytesPath);
      const afterB = await readBytes(bBytesPath);
      const aWrites = occurrences(afterA, subject) - occurrences(beforeA, subject);
      const bWrites = occurrences(afterB, subject) - occurrences(beforeB, subject);
      assert.equal(aWrites, 1);
      assert.equal(bWrites, UNSAFE_CASES.has(caseId) ? 0 : 1);
      caseReceipt.armA.ptyWrites += aWrites;
      if (UNSAFE_CASES.has(caseId)) {
        caseReceipt.armA.unsafeWrites += aWrites;
      }
      if (caseId === "active-turn") {
        const draft = caseReceipt.partialDraft;
        const draftOffsetA = afterA.indexOf(draft);
        const draftOffsetB = afterB.indexOf(draft);
        const dingOffsetA = afterA.indexOf(subject, draftOffsetA + Buffer.byteLength(draft));
        assert.ok(draftOffsetA >= 0, "arm A partial draft disappeared");
        assert.ok(draftOffsetB >= 0, "arm B partial draft disappeared");
        assert.ok(dingOffsetA >= draftOffsetA + Buffer.byteLength(draft),
          "arm A DING was not observed after the live partial draft");
        assert.equal(occurrences(afterB, subject), occurrences(beforeB, subject));
        caseReceipt.observedPartialDraftCollision = {
          armA: true,
          armB: false,
          observation: "DING PTY bytes arrived after the live partial draft",
        };
      }

      const archivedA = await readAndArchive("matrix.a", filenameA, message);
      const archivedB = await readAndArchive("matrix.b", filenameB, message);
      deliveredA.push(archivedA);
      deliveredB.push(archivedB);
      caseReceipt.messages.push({ id, sha256: message.sha256, filenameA, filenameB });
      await waitForNoOwnership(filenameB);

      processedMessages += 1;
    }
    receipt.cases.push(caseReceipt);
  }

  assert.equal(processedMessages, TOTAL_MESSAGES);
  assert.deepEqual(
    deliveredA.map(({ id, sha256 }) => ({ id, sha256 })),
    deliveredB.map(({ id, sha256 }) => ({ id, sha256 })),
  );
  assert.equal(new Set(deliveredA.map(({ id }) => id)).size, TOTAL_MESSAGES);
  assert.equal(new Set(deliveredB.map(({ id }) => id)).size, TOTAL_MESSAGES);
  const archiveA = JSON.parse((await runSt2([
    "message", "ls", "matrix.a", "--archive", "--json", "--catalog", net, "--host", "matrix", "--as", "matrix.a",
  ])).stdout);
  const archiveB = JSON.parse((await runSt2([
    "message", "ls", "matrix.b", "--archive", "--json", "--catalog", net, "--host", "matrix", "--as", "matrix.b",
  ])).stdout);
  assert.equal(archiveA.length, TOTAL_MESSAGES);
  assert.equal(archiveB.length, TOTAL_MESSAGES);
  assert.equal(await inboxCount("matrix.a"), 0);
  assert.equal(await inboxCount("matrix.b"), 0);

  const proofs = await jsonLines(proofPath);
  assert.ok(proofs.length >= 2);
  const expectedArgv = [
    "--control", controlPath,
    "--proof", proofPath,
    "--trace", tracePath,
    "space arg",
    "; touch forbidden",
  ];
  for (const proof of proofs) {
    assert.deepEqual(proof.argv, expectedArgv);
    assert.equal(proof.env.CATALOG, net);
    assert.equal(proof.env.ST_ROOT, net);
    assert.equal(proof.env.ST_AGENT, "matrix.b");
    assert.equal(proof.env.PTY_ROOT, ptyRoot);
    assert.equal(proof.env.ADAPTER_ROOT, catalog);
    assert.equal(proof.env.ADAPTER_CONTROL, controlPath);
    assert.equal(proof.env.ADAPTER_PROOF, proofPath);
    assert.equal(proof.env.ADAPTER_TRACE, tracePath);
    assert.equal(proof.env.PTY_PACKAGE_ROOT, ptyPackageRoot);
    assert.equal(proof.env.PATH, runtimePath);
  }
  assert.equal(await exists(path.join(net, "agents", "matrix", "b", "forbidden")), false);
  assert.equal(await exists(path.join(net, "forbidden")), false);

  const aLog = await readFile(sidecarLog("matrix.a"), "utf8");
  const bLogs = [];
  for (const file of [sidecarLog("matrix.b"), `${sidecarLog("matrix.b")}.1`]) {
    if (await exists(file)) bLogs.push(await readFile(file, "utf8"));
  }
  assert.match(aLog, /"result":"fallback"/);
  assert.ok(bLogs.every((log) => !log.includes('"result":"fallback"')));
  assert.ok(bLogs.some((log) => log.includes('"result":"pty-owned"')));
  assert.ok(bLogs.some((log) => log.includes('"result":"hook-owned"')));

  const unsafeA = receipt.cases.reduce((sum, entry) => sum + entry.armA.unsafeWrites, 0);
  const unsafeB = receipt.cases
    .filter((entry) => UNSAFE_CASES.has(entry.caseId))
    .reduce((sum, entry) => sum + entry.armB.ptyWrites, 0);
  const hookOwnedB = receipt.cases.reduce((sum, entry) => sum + entry.armB.hookOwned, 0);
  const guardedB = receipt.cases.reduce((sum, entry) => sum + entry.armB.ptyWrites, 0);
  const observedPartialDraftCollisionsA = receipt.cases
    .filter((entry) => entry.observedPartialDraftCollision?.armA)
    .length;
  const observedPartialDraftCollisionsB = receipt.cases
    .filter((entry) => entry.observedPartialDraftCollision?.armB)
    .length;
  const activeTurn = receipt.cases.find((entry) => entry.caseId === "active-turn");
  assert.deepEqual(activeTurn.partialDraftLiveBeforeDelivery, { armA: true, armB: true });
  assert.deepEqual(activeTurn.observedPartialDraftCollision, {
    armA: true,
    armB: false,
    observation: "DING PTY bytes arrived after the live partial draft",
  });
  receipt.taskEnvironment = {
    correctedArgvExpansion: true,
    noShell: true,
    adapterLaunches: proofs.length,
    sidecarExecutables,
    exactArgv: expectedArgv,
  };
  receipt.summary = {
    deliveryParity: true,
    deliveredMessages: TOTAL_MESSAGES,
    armAUnsafeWrites: unsafeA,
    armBUnsafeWrites: unsafeB,
    armAObservedPartialDraftCollisions: observedPartialDraftCollisionsA,
    armBObservedPartialDraftCollisions: observedPartialDraftCollisionsB,
    armBGuardedWrites: guardedB,
    armBHookOwned: hookOwnedB,
  };
  assert.equal(unsafeA, 6);
  assert.equal(unsafeB, 0);
  assert.equal(observedPartialDraftCollisionsA, 1);
  assert.equal(observedPartialDraftCollisionsB, 0);
  assert.equal(guardedB, 5);
  assert.equal(hookOwnedB, 6);
} finally {
  aPublisher?.close();
  aPublisher = null;
  await runSt2(["down", "--catalog", net, "--host", "matrix"]).catch((error) => {
    cleanupErrors.push(`st2 down: ${error.message}`);
  });
  await waitForExecTasksDead().catch((error) => cleanupErrors.push(error.message));
  await waitForTrackedProcessesDead().catch((error) => cleanupErrors.push(error.message));
  await removeAllSessions().catch((error) => cleanupErrors.push(error.message));
}

assert.deepEqual(cleanupErrors, []);
receipt.cleanup.sessions = (await listSessions()).length;
const trackedProcesses = new Map();
for (const launch of sidecarExecutables) {
  for (const member of launch.members) {
    trackedProcesses.set(`${member.pid}:${member.processStart}`, member);
  }
}
let liveCleanupProcesses = 0;
for (const identity of trackedProcesses.values()) {
  if (await processIdentityAlive(identity)) liveCleanupProcesses += 1;
}
receipt.cleanup.execProcesses = liveCleanupProcesses;
receipt.cleanup.trackedProcesses = trackedProcesses.size;
assert.equal(receipt.cleanup.sessions, 0);
assert.equal(receipt.cleanup.execProcesses, 0);

await writeFile(
  path.join(catalog, "integrated-ab-receipt.json"),
  `${JSON.stringify(receipt, null, 2)}\n`,
);

console.log("ST2-RICH-AB-EXACT-ARTIFACTS-GREEN-57i1");
console.log("ST2-RICH-AB-TASK-ENV-GREEN-57i1");
console.log("ST2-RICH-AB-SELECTION-GREEN-57i1");
console.log("ST2-RICH-AB-DURABILITY-GREEN-57i1");
console.log("ST2-RICH-AB-IMPROVEMENT-GREEN-57i1");
console.log("ST2-RICH-AB-OWNERSHIP-GREEN-57i1");
console.log("ST2-RICH-AB-HOLD-RESTART-GREEN-57i1");
console.log("ST2-RICH-AB-FIFO-GREEN-57i1");
console.log("ST2-RICH-AB-CLEANUP-MODEL-FREE-GREEN-57i1");
