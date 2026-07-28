function validateUrl(value) {
  if (typeof value !== "string") {
    throw new TypeError("destination URL must be a string");
  }
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new TypeError("destination URL must be valid");
  }
  if (parsed.protocol !== "https:") {
    throw new TypeError("destination URL must use HTTPS");
  }
}

export function createDestination({ url } = {}) {
  validateUrl(url);
  return Object.freeze({ url });
}

