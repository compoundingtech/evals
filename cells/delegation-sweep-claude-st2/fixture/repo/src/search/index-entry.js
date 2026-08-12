import { titleFor } from "../compat/title-helpers.js";

export function indexEntry(note) {
  return { id: note.id, title: titleFor(note), tags: note.tags ?? [] };
}
