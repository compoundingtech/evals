import { modernTitle } from "../modern/title.js";

// The audit report names the legacy path in its human-readable output only.
export function auditReport(notes) {
  const unmigrated = notes.filter((note) => !(note.heading ?? "").trim()).length;
  return {
    titles: notes.map((note) => modernTitle(note)),
    warning: unmigrated ? `${unmigrated} note(s) would differ under legacyTitle` : "",
  };
}
