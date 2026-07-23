import { add } from "./add.js";
import { list } from "./list.js";
import { done } from "./done.js";
import { remove } from "./remove.js";
import { fail } from "../result.js";

// The command registry. Every command is listed here so `dispatch` can find it by name.
export const commands = [add, list, done, remove];

export function dispatch(name, args, store) {
  const cmd = commands.find((c) => c.name === name);
  if (!cmd) return fail("unknown_command", `no such command: ${name}`);
  return cmd.run(args, store);
}
