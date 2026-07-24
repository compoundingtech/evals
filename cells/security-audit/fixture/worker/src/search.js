import { readNote, listNotes } from "./notes.js";

// Search all notes for a user-supplied pattern.
export function searchNotes(query) {
  const re = new RegExp(query);
  return listNotes().filter((n) => re.test(readNote(n)));
}
