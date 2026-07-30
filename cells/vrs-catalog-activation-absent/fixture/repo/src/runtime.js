import { randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

function registryPath(root, host) {
  return path.join(root, "runtime", `${host}.json`);
}

async function loadRegistry(root, host) {
  try {
    return JSON.parse(await readFile(registryPath(root, host), "utf8"));
  } catch (error) {
    if (error.code === "ENOENT") return { host, services: [] };
    throw error;
  }
}

export async function convergeHost({ root, host, catalog, controllerId }) {
  const previous = await loadRegistry(root, host);
  const actions = previous.services.map((service) => ({
    type: "stop",
    service: service.name,
    instanceId: service.instanceId,
  }));
  const services = (catalog?.services ?? []).map((name) => {
    const service = { name, instanceId: randomUUID(), controllerId };
    actions.push({ type: "start", service: name, instanceId: service.instanceId });
    return service;
  });
  const registry = { host, services };
  await mkdir(path.dirname(registryPath(root, host)), { recursive: true });
  await writeFile(registryPath(root, host), `${JSON.stringify(registry, null, 2)}\n`);
  return { registry, actions };
}
