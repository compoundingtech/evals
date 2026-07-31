import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import path from "node:path";

import { candidateDigest } from "./candidate.js";

function incomingPath(root, host) {
  return path.join(root, "incoming", host, "candidate.json");
}

function activePath(root, host) {
  return path.join(root, "active", host, "receipt.json");
}

async function readJson(file) {
  return JSON.parse(await readFile(file, "utf8"));
}

function validCandidate(candidate, host) {
  return (
    candidate &&
    candidate.complete === true &&
    candidate.host === host &&
    Number.isSafeInteger(candidate.version) &&
    candidate.version >= 0 &&
    Array.isArray(candidate.services) &&
    candidate.services.every((service) => typeof service === "string") &&
    new Set(candidate.services).size === candidate.services.length &&
    candidate.digest === candidateDigest(candidate)
  );
}

export async function loadActive(root, host) {
  try {
    return await readJson(activePath(root, host));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

export async function activateCandidate(root, host, { afterStage } = {}) {
  const current = await loadActive(root, host);
  let candidate;
  try {
    candidate = await readJson(incomingPath(root, host));
  } catch (error) {
    if (error.code === "ENOENT" || error instanceof SyntaxError) {
      return { status: error.code === "ENOENT" ? "missing" : "invalid", active: current };
    }
    throw error;
  }

  if (!validCandidate(candidate, host)) {
    return { status: "invalid", active: current };
  }
  if (current && candidate.version <= current.version) {
    return { status: "not-newer", active: current };
  }

  const target = activePath(root, host);
  const staged = `${target}.staged`;
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(staged, `${JSON.stringify(candidate, null, 2)}\n`);
  try {
    if (afterStage) await afterStage();
    await rename(staged, target);
  } catch (error) {
    await unlink(staged).catch(() => {});
    throw error;
  }
  return { status: "activated", active: candidate };
}
