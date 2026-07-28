function validateChecks(checks) {
  if (!Array.isArray(checks)) {
    throw new TypeError("checks must be an array");
  }
  for (const check of checks) {
    if (check === null || typeof check !== "object" || typeof check.ok !== "boolean") {
      throw new TypeError("each check must have a boolean ok field");
    }
  }
}

export function countPassing(checks) {
  validateChecks(checks);
  return checks.filter((check) => check.ok).length;
}

export function summarizeChecks(checks) {
  validateChecks(checks);
  const passing = checks.filter((check) => check.ok).length;
  return {
    total: checks.length,
    passing,
    failing: checks.length - passing,
  };
}

