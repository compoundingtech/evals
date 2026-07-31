import { appendFile, readFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

function option(name) {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) {
    throw new Error(`${name} is required`);
  }
  return process.argv[index + 1];
}

const controlPath = option("--control");
const proofPath = option("--proof");
const tracePath = option("--trace");
const session = process.env.ST_AGENT;
const packageRoot = process.env.PTY_PACKAGE_ROOT;
if (!session || !packageRoot) throw new Error("managed adapter environment is incomplete");

await appendFile(
  proofPath,
  `${JSON.stringify({
    pid: process.pid,
    argv: process.argv.slice(2),
    env: {
      CATALOG: process.env.CATALOG,
      ST_ROOT: process.env.ST_ROOT,
      ST_AGENT: process.env.ST_AGENT,
      PTY_ROOT: process.env.PTY_ROOT,
      ADAPTER_ROOT: process.env.ADAPTER_ROOT,
      ADAPTER_CONTROL: process.env.ADAPTER_CONTROL,
      ADAPTER_PROOF: process.env.ADAPTER_PROOF,
      ADAPTER_TRACE: process.env.ADAPTER_TRACE,
      PTY_PACKAGE_ROOT: process.env.PTY_PACKAGE_ROOT,
      PATH: process.env.PATH,
    },
  })}\n`,
);

const client = await import(pathToFileURL(path.join(packageRoot, "dist", "client-api.js")));
const { connectActivityPublisher, queryStats } = client;

async function sleep(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitForSession() {
  for (let attempt = 0; attempt < 400; attempt += 1) {
    try {
      const stats = await queryStats(session);
      if (stats.process.alive) return stats;
    } catch {}
    await sleep(25);
  }
  throw new Error(`timed out waiting for PTY session ${session}`);
}

await waitForSession();
const publisher = await connectActivityPublisher(session, {
  producerEpoch: `st2-rich-adapter-${process.pid}`,
  source: "generic-evals-57",
});

function ptyState(state) {
  if (state === "child") return "child_command";
  if (state === "unknown") return "active";
  return state;
}

async function publish(command) {
  let finalEvent;
  for (let observation = 0; observation < 2; observation += 1) {
    await publisher.publish(ptyState(command.state), { turnId: command.id });
    const stats = await queryStats(session);
    finalEvent = {
      v: 1,
      kind: "activity",
      session,
      incarnation: stats.activity.producerEpoch,
      generation: stats.generation,
      sequence: stats.activity.sequence,
      state: command.state,
      inputBuffer: command.inputBuffer,
      validForMs: command.validForMs,
      reason: `fixture:${command.id}:${observation + 1}`,
    };
    process.stdout.write(`${JSON.stringify(finalEvent)}\n`);
  }
  await appendFile(
    tracePath,
    `${JSON.stringify({ id: command.id, event: finalEvent })}\n`,
  );
}

let seen = null;
let running = false;
const timer = setInterval(async () => {
  if (running) return;
  running = true;
  try {
    const command = JSON.parse(await readFile(controlPath, "utf8"));
    if (command.id !== seen) {
      seen = command.id;
      await publish(command);
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      await appendFile(tracePath, `${JSON.stringify({ error: error.message })}\n`);
    }
  } finally {
    running = false;
  }
}, 20);

function stop() {
  clearInterval(timer);
  publisher.close();
  process.exit(0);
}

process.on("SIGTERM", stop);
process.on("SIGINT", stop);
