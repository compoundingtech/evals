export function sortNotes(notes) {
  return [...notes].sort((a, b) => (a.heading ?? "").localeCompare(b.heading ?? ""));
}
