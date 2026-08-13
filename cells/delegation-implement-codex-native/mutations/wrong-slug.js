export function slugify(text) {
  return (text ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "note";
}

// Planted negative: the suffix counter is global across bases, so the third "Alpha" becomes alpha-4.
export function slugsFor(notes) {
  let n = 0;
  const seen = new Set();
  return notes.map((note) => {
    const base = slugify(note.heading);
    n += 1;
    if (!seen.has(base)) {
      seen.add(base);
      return base;
    }
    return `${base}-${n}`;
  });
}
