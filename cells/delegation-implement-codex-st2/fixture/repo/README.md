# noteflow

A small synthetic note pipeline. Notes carry `{ id, heading, body, tags }` and flow through
resolution (title), search (index + query), export (markdown), and rendering (card/list/preview).

Title resolution has two generations:

- `src/legacy/title.js` — the original `legacyTitle()` derivation.
- `src/modern/title.js` — the replacement `modernTitle()` derivation.

`src/compat/` exists so that callers could migrate gradually. The migration is unfinished.

Run the suite with `node --test`.
