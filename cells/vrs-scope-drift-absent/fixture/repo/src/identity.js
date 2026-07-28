const ID_PATTERN = /^[a-z][a-z0-9.-]*$/;

function validateId(id) {
  if (typeof id !== "string" || !ID_PATTERN.test(id)) {
    throw new TypeError("agent id must be a lowercase identifier");
  }
}

export function createAgent({ id, displayName } = {}) {
  validateId(id);
  const identity = { kind: "agent", id };
  if (displayName !== undefined) {
    if (typeof displayName !== "string" || displayName.length === 0) {
      throw new TypeError("displayName must be a non-empty string");
    }
    identity.displayName = displayName;
  }
  return Object.freeze(identity);
}

export function parseIdentity(value) {
  if (typeof value !== "string" || !value.startsWith("agent:")) {
    throw new TypeError("identity must use the agent:<id> form");
  }
  return createAgent({ id: value.slice("agent:".length) });
}
