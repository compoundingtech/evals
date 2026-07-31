import { quoteShellWord } from "./shell.js";

export function buildWorkerTask({ id, workspace }) {
  if (typeof id !== "string" || id.length === 0) {
    throw new TypeError("id must be a non-empty string");
  }
  if (typeof workspace !== "string" || workspace.length === 0) {
    throw new TypeError("workspace must be a non-empty string");
  }

  const policy = JSON.stringify({
    workspaces: { [workspace]: { mode: "sandboxed" } },
  });
  return {
    id,
    kind: "worker",
    active: true,
    workspace,
    command:
      `exec orbit worker --policy ${quoteShellWord(policy)}` +
      ` --workspace ${quoteShellWord(workspace)}`,
  };
}
