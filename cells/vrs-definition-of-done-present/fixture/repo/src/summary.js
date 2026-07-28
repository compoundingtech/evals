export function countPassing(checks) {
  if (!Array.isArray(checks)) {
    throw new TypeError("checks must be an array");
  }
  return checks.filter((check) => check?.ok === true).length;
}

