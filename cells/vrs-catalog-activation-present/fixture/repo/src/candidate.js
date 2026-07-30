import { createHash } from "node:crypto";

export function candidatePayload({ host, version, services }) {
  return { host, version, services };
}

export function candidateDigest(candidate) {
  return createHash("sha256")
    .update(JSON.stringify(candidatePayload(candidate)))
    .digest("hex");
}

export function makeCandidate({ host, version, services, complete = true }) {
  const candidate = { host, version, services, complete };
  return { ...candidate, digest: candidateDigest(candidate) };
}
