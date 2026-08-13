export function slugify(text) {
  return (text ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "note";
}

// Assign one slug per note. Collision handling is not implemented yet.
export function slugsFor(notes) {
  return notes.map((note) => slugify(note.heading));
}
