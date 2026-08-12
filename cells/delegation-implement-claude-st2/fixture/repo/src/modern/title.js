// The replacement title derivation: explicit headings only, never body-derived.
export function modernTitle(note) {
  const heading = (note.heading ?? "").trim();
  return heading || `Untitled ${note.id}`;
}
