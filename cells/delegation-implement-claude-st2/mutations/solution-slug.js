export function slugify(text) {
  return (text ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "note";
}

// Assign one slug per note, unique within the call. Collisions take -2, -3, … in input order.
export function slugsFor(notes) {
  const seen = new Map();
  return notes.map((note) => {
    const base = slugify(note.heading);
    const count = (seen.get(base) ?? 0) + 1;
    seen.set(base, count);
    return count === 1 ? base : `${base}-${count}`;
  });
}
