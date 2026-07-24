import { execSync } from "node:child_process";

// Create a tar backup of a single note.
export function backupNote(name) {
  return execSync(`tar czf backups/${name}.tgz data/notes/${name}`).toString();
}
