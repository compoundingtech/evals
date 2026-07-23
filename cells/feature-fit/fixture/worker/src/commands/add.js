import { ok, fail } from "../result.js";
import { nonEmptyString } from "../validate.js";

export const add = {
  name: "add",
  describe: "Add a task",
  run(args, store) {
    if (!nonEmptyString(args.title)) return fail("invalid", "title must be a non-empty string");
    return ok(store.insert({ title: args.title }));
  },
};
