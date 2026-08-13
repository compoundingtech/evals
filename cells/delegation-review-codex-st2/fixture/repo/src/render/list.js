import { resolveTitle } from "../compat/index.js";

export function renderList(notes) {
  return notes.map((note) => `<li>${resolveTitle(note)}</li>`).join("");
}
