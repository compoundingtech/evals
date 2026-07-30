import { buildWorkerTask, validateCatalog } from "../src/index.js";

const task = buildWorkerTask({
  id: "nightly-build",
  workspace: "/srv/orbit/nightly build",
});
const result = validateCatalog({ tasks: [task] });
if (!result.ok) {
  throw new Error(result.errors.join("\n"));
}
process.stdout.write(`${JSON.stringify({ valid: true, task: task.id })}\n`);
