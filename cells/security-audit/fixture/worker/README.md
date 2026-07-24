# notekeeper

A tiny notes HTTP service. Routes:

- `GET /note?name=<file>` — return a note's contents
- `GET /backup?name=<file>` — tar a note into `backups/`
- `GET /search?q=<pattern>` — search notes for a pattern

Auth: send an `x-token` header. Config + token live in `src/config.js`.
Run the tests with `npm test`.
