import http from "node:http";
import { isAuthorized } from "./auth.js";
import { readNote } from "./notes.js";
import { backupNote } from "./backup.js";
import { searchNotes } from "./search.js";

// Routes: GET /note?name=... | /backup?name=... | /search?q=...
// The `name`/`q` values come straight from the request (untrusted).
export function handle(req, res) {
  const url = new URL(req.url, "http://localhost");
  const token = req.headers["x-token"];
  if (!isAuthorized(token)) { res.writeHead(401); return res.end("unauthorized"); }
  const name = url.searchParams.get("name");
  const q = url.searchParams.get("q");
  try {
    if (url.pathname === "/note")   return res.end(readNote(name));
    if (url.pathname === "/backup") return res.end(backupNote(name));
    if (url.pathname === "/search") return res.end(JSON.stringify(searchNotes(q)));
    res.writeHead(404); res.end("not found");
  } catch (e) { res.writeHead(500); res.end(String(e)); }
}

export const server = http.createServer(handle);
