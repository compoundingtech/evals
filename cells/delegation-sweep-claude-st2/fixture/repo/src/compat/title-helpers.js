import { resolveTitle } from "./index.js";

// Convenience wrapper used by index writers. This one really does call through.
export function titleFor(note) {
  return resolveTitle(note);
}

export function titlesFor(notes) {
  return notes.map((note) => titleFor(note));
}
