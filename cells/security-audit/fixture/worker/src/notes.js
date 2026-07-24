import fs from "node:fs";
import path from "node:path";
import { NOTES_DIR } from "./config.js";

// Read a note by name.
export function readNote(name) {
  const p = path.join(NOTES_DIR, name);
  return fs.readFileSync(p, "utf8");
}

// List note names.
export function listNotes() {
  return fs.readdirSync(NOTES_DIR);
}
