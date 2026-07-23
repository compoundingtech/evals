# feature-fit — add a feature that fits the house conventions

**What it evaluates.** Feature-in-existing-code — harder than greenfield because you must **read the code
and match it**. The `tasklit` library has strong, consistent conventions across 4 commands (a Result
pattern that never throws, shared validators, a `{ name, describe, run }` module shape + a dispatch
registry, one test per command). A supervisor (`feat.sup`, coordinate-only) delegates to a specialist
(`feat.dev`, owns the repo) to **add a `rename` command** — and the request deliberately does **not** list
the conventions. Reading the existing commands, inferring the style, and slotting the feature in
idiomatically (not a functional-but-alien bolt-on) is the test.

**Run it:** `st2 eval ./cells/feature-fit/`

`st2 eval` copies the fixture into a fresh catalog, boots the team, delivers `task.md` to `feat.sup`, runs
to the supervisor's confirmation (or `max-timeout`), then runs the judges → verdict.

## The folder

| path | what it is |
| --- | --- |
| `feature-fit.kdl` | the whole eval: the `feat` team (sup + dev) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the feature request delivered to `feat.sup` (does not enumerate the conventions) |
| `fixture/` | the pre-built world, copied 1:1: `worker/` (the `tasklit` repo, green suite, base commit + owner-pinned author `feat.dev`, git db `worker/_git` → `.git` on copy) and `sup/` (coordinate-only, no repo). Each holds an `st2`-native persona. |
| `judges/` | the held-out bash judges (below) |

## What makes it pass (all judges must pass — the team never sees these)

- **isolation** (`judges/isolation.sh`) — only `feat.dev` authored commits; the supervisor owns no repo.
- **visible suite** (`judges/suite.sh`) — `node --test` is green on HEAD (existing behavior preserved).
- **functional** (`judges/functional.sh`) — `rename` works via `dispatch` across four cases, which enforces
  **registration** + the **Result shape** (a throw, missing registration, or wrong codes fail here).
- **test added** (`judges/test-added.sh`) — a matching test at `test/commands/rename.test.js`.
- **convention fit** (`judges/convention-fit.sh`) — the discriminator: hard gates on **no `throw`** (Result
  pattern) + **registered** in `index.js`; plus non-gating signals (module shape, `ok()`/`fail()` from
  `result.js`, reuse of `validate.js`) that surface a functional-but-alien implementation.
