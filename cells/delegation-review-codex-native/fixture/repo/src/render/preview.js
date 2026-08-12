import { modernTitle } from "../modern/title.js";

// TODO(migration): the card renderer still goes through legacyTitle(); this one does not.
export function renderPreview(note) {
  return `${modernTitle(note)} — ${(note.body ?? "").slice(0, 40)}`;
}
