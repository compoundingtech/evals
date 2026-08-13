import { legacyTitle } from "../legacy/title.js";

export function renderCard(note) {
  return `<article><h3>${legacyTitle(note)}</h3><p>${note.body ?? ""}</p></article>`;
}
