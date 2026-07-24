import { ok, fail } from "../result.js";
import { positiveInt } from "../validate.js";

export const remove = {
  name: "remove",
  describe: "Remove a task by id",
  run(args, store) {
    if (!positiveInt(args.id)) return fail("invalid", "id must be a positive integer");
    const task = store.find(args.id);
    if (!task) return fail("not_found", `no task with id ${args.id}`);
    const tasks = store.all();
    tasks.splice(tasks.indexOf(task), 1);
    return ok(task);
  },
};
