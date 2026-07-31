import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
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
  const byName = new Map(previous.services.map((service) => [service.name, service]));
  const desired = new Set(catalog?.services ?? previous.services.map((item) => item.name));
  const services = [];
  const actions = [];

  for (const name of desired) {
    const existing = byName.get(name);
    if (!existing) {
      const service = { name, instanceId: randomUUID(), controllerId };
      services.push(service);
      actions.push({ type: "start", service: name, instanceId: service.instanceId });
    } else if (existing.controllerId !== controllerId) {
      services.push({ ...existing, controllerId });
      actions.push({ type: "adopt", service: name, instanceId: existing.instanceId });
    } else {
      services.push(existing);
      actions.push({ type: "keep", service: name, instanceId: existing.instanceId });
    }
  }
  for (const existing of previous.services) {
    if (!desired.has(existing.name)) {
      actions.push({
        type: "stop",
        service: existing.name,
        instanceId: existing.instanceId,
      });
    }
  }

  const registry = { host, services };
  const target = registryPath(root, host);
  const staged = `${target}.staged`;
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(staged, `${JSON.stringify(registry, null, 2)}\n`);
  await rename(staged, target);
  return { registry, actions };
}
