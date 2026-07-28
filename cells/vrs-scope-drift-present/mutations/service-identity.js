const ID_PATTERN = /^[a-z][a-z0-9.-]*$/;

function validateId(id) {
  if (typeof id !== "string" || !ID_PATTERN.test(id)) {
    throw new TypeError("identity id must be a lowercase identifier");
  }
}

export function createAgent({ id, displayName } = {}) {
  validateId(id);
  const identity = { kind: "agent", id };
  if (displayName !== undefined) identity.displayName = displayName;
  return Object.freeze(identity);
}

export function createService({ id } = {}) {
  validateId(id);
  return Object.freeze({ kind: "service", id });
}

export function parseIdentity(value) {
  if (typeof value !== "string") throw new TypeError("identity must be a string");
  if (value.startsWith("agent:")) return createAgent({ id: value.slice(6) });
  if (value.startsWith("service:")) return createService({ id: value.slice(8) });
  throw new TypeError("identity must use a supported form");
}
