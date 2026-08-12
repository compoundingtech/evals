// The original title derivation. Retained until every caller migrates.
export function legacyTitle(note) {
  const heading = (note.heading ?? "").trim();
  if (heading) return heading;
  const firstLine = (note.body ?? "").split("\n")[0].trim();
  return firstLine || `note-${note.id}`;
}
