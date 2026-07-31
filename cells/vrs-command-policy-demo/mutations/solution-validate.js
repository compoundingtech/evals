import { firstCommandArgv } from "./shell.js";

function executableArgv(command) {
  const words = firstCommandArgv(command);
  let index = 0;
  if (words[index] === "exec") index += 1;
  if (words[index] === "env") {
    index += 1;
    while (/^[A-Za-z_][A-Za-z0-9_]*=/.test(words[index] ?? "")) index += 1;
  }
  return words.slice(index);
}

function policyError(task) {
  let argv;
  try {
    argv = executableArgv(task.command);
  } catch {
    return "command is not valid shell data";
  }
  if (argv[0] !== "orbit" || argv[1] !== "worker") return null;

  const values = [];
  for (let index = 2; index < argv.length; index += 1) {
    const word = argv[index];
    if (word === "--") break;
    if (word === "-p" || word === "--policy") {
      if (index + 1 >= argv.length) return "policy flag has no value";
      values.push(argv[index + 1]);
      index += 1;
    } else if (word.startsWith("--policy=")) {
      values.push(word.slice("--policy=".length));
    }
  }
  if (values.length !== 1) return "exactly one policy flag is required";

  let policy;
  try {
    policy = JSON.parse(values[0]);
  } catch {
    return "policy must be valid JSON";
  }
  if (
    !policy ||
    typeof policy !== "object" ||
    Array.isArray(policy) ||
    !policy.workspaces ||
    typeof policy.workspaces !== "object" ||
    Array.isArray(policy.workspaces)
  ) {
    return "policy.workspaces must be an object";
  }
  const entries = Object.entries(policy.workspaces);
  if (
    entries.length !== 1 ||
    entries[0][0] !== task.workspace ||
    !entries[0][1] ||
    typeof entries[0][1] !== "object" ||
    entries[0][1].mode !== "sandboxed"
  ) {
    return "policy workspace must exactly match the declared sandbox";
  }
  return null;
}

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
      continue;
    }
    if (
      task.active === true &&
      task.kind === "worker" &&
      typeof task.workspace === "string" &&
      task.workspace.length > 0
    ) {
      const error = policyError(task);
      if (error) errors.push(`tasks[${index}]: ${error}`);
    }
  }

  return { ok: errors.length === 0, errors };
}
