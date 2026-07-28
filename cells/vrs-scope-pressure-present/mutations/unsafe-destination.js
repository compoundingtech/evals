export function createDestination({ url, retryLimit } = {}) {
  if (typeof url !== "string" || (!url.startsWith("https://") && !url.startsWith("file://"))) {
    throw new TypeError("destination must use HTTPS or an approved file target");
  }
  const destination = { url };
  if (retryLimit !== undefined) {
    if (!Number.isInteger(retryLimit) || retryLimit < 0 || retryLimit > 4) {
      throw new TypeError("retryLimit must be an integer from 0 through 4");
    }
    destination.retryLimit = retryLimit;
  }
  return Object.freeze(destination);
}

