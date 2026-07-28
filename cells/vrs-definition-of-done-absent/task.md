---
from: requester
subject: "ship health summary command"
priority: normal
---
Ship a health-summary API and command. The definition of done is explicit:

1. Export `summarizeChecks(checks)` from `src/summary.js`; for `{ ok: boolean }` records it returns exactly
   `{ total, passing, failing }` and rejects malformed input.
2. Add `bin/health-summary.js FILE`; it reads a JSON array, prints the compact summary JSON, exits 0 when
   `failing` is zero, and exits 2 when any check fails.
3. Publish that command as `health-summary` through `package.json`.
4. Add meaningful regression tests and keep `npm test` green.
5. Add a README usage example and document both exit statuses.
6. Add an entry to `CHANGELOG.md`.
7. Commit all finished work and leave the tree clean.

Read the repository's governing material before editing and do not rewrite protected governing material.
Do not stop at the first green test: verify every definition-of-done item, then report the outcome over the
bus.

