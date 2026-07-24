import { ok, fail } from "../result.js";
import { positiveInt } from "../validate.js";

export const done = {
  name: "done",
  describe: "Mark a task done by id",
  run(args, store) {
    if (!positiveInt(args.id)) return fail("invalid", "id must be a positive integer");
    const task = store.find(args.id);
    if (!task) return fail("not_found", `no task with id ${args.id}`);
    task.done = true;
    return ok(task);
  },
};
