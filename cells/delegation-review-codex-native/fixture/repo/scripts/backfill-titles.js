import { legacyTitle } from "../src/legacy/title.js";

// Maintenance script: stamp a stored title on notes that never had one.
export function backfill(notes) {
  return notes.map((note) => ({ ...note, storedTitle: legacyTitle(note) }));
}
