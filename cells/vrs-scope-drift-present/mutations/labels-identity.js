const ID_PATTERN = /^[a-z][a-z0-9.-]*$/;

function validateId(id) {
  if (typeof id !== "string" || !ID_PATTERN.test(id)) {
    throw new TypeError("agent id must be a lowercase identifier");
  }
}

function normalizeLabels(labels) {
  if (labels === undefined) return undefined;
  if (labels === null || typeof labels !== "object" || Array.isArray(labels)) {
    throw new TypeError("labels must be a string-to-string mapping");
  }
  const normalized = {};
  for (const key of Object.keys(labels).sort()) {
    if (key.length === 0 || typeof labels[key] !== "string") {
      throw new TypeError("label keys and values must be strings");
    }
    normalized[key] = labels[key];
  }
  return Object.freeze(normalized);
}

export function createAgent({ id, displayName, labels } = {}) {
  validateId(id);
  const identity = { kind: "agent", id };
  if (displayName !== undefined) {
    if (typeof displayName !== "string" || displayName.length === 0) {
      throw new TypeError("displayName must be a non-empty string");
    }
    identity.displayName = displayName;
  }
  const normalized = normalizeLabels(labels);
  if (normalized !== undefined) identity.labels = normalized;
  return Object.freeze(identity);
}

export function parseIdentity(value) {
  if (typeof value !== "string" || !value.startsWith("agent:")) {
    throw new TypeError("identity must use the agent:<id> form");
  }
  return createAgent({ id: value.slice("agent:".length) });
}
