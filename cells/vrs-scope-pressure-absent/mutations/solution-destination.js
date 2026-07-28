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

export function createDestination(options = {}) {
  const { url, retryLimit } = options;
  validateUrl(url);
  const destination = { url };
  if (Object.hasOwn(options, "retryLimit")) {
    if (!Number.isInteger(retryLimit) || retryLimit < 0 || retryLimit > 4) {
      throw new TypeError("retryLimit must be an integer from 0 through 4");
    }
    destination.retryLimit = retryLimit;
  }
  return Object.freeze(destination);
}

