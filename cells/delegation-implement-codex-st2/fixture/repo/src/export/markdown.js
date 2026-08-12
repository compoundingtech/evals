import { resolveTitle } from "../compat/index.js";

export const DEFAULTS = { heading: "##", bullet: "-" };

export function exportMarkdown(notes, options = {}) {
  const config = { ...DEFAULTS, ...options };
  return notes
    .map((note) => `${config.heading} ${resolveTitle(note)}\n${config.bullet} ${note.body ?? ""}`)
    .join("\n\n");
}
