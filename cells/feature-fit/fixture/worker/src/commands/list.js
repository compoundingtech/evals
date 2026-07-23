import { ok } from "../result.js";

export const list = {
  name: "list",
  describe: "List all tasks",
  run(args, store) {
    return ok(store.all());
  },
};
