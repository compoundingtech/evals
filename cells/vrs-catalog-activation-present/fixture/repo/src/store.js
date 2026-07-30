import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

function incomingPath(root, host) {
  return path.join(root, "incoming", host, "candidate.json");
}

function activePath(root) {
  return path.join(root, "active", "catalog.json");
}

async function readJson(file) {
  return JSON.parse(await readFile(file, "utf8"));
}

export async function loadActive(root, _host) {
  try {
    return await readJson(activePath(root));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export async function activateCandidate(root, host, _options = {}) {
  const candidate = await readJson(incomingPath(root, host));
  if (!candidate.complete) {
    throw new Error("candidate is incomplete");
  }
  await mkdir(path.dirname(activePath(root)), { recursive: true });
  await writeFile(activePath(root), `${JSON.stringify(candidate, null, 2)}\n`);
  return { status: "activated", active: candidate };
}
