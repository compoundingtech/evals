export function validateCatalog(catalog) {
  const errors = [];
  if (!catalog || !Array.isArray(catalog.tasks)) {
    return { ok: false, errors: ["catalog.tasks must be an array"] };
  }

  for (const [index, task] of catalog.tasks.entries()) {
    if (!task || typeof task !== "object") {
      errors.push(`tasks[${index}] must be an object`);
      continue;
    }
    if (typeof task.id !== "string" || task.id.length === 0) {
      errors.push(`tasks[${index}].id must be a non-empty string`);
    }
    if (typeof task.command !== "string" || task.command.length === 0) {
      errors.push(`tasks[${index}].command must be a non-empty string`);
    }
  }

  return { ok: errors.length === 0, errors };
}
