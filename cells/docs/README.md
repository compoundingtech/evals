# docs — document a library so a cold reader can use it

**What it evaluates.** Documentation that actually **works**: docs a fresh reader can use with only the
docs (not the source). The `checkout` cart library has three non-obvious, silent-failure contracts a
newcomer cannot guess — money is integer **cents**, tax is **basis points** (800 = 8%); the API is
**immutable** (methods return a new cart — discard the return and it's a silent no-op); and you must
**`seal()` before `total()`** or `total()` silently omits promo + tax. A supervisor (`doc.sup`,
coordinate-only) delegates to a writer (`doc.writer`, owns the repo) to document the library so a cold
reader can use it correctly. It's a **docs lane** — `src/` must not change.

**Run it:** `st2 eval ./cells/docs/`

`st2 eval` copies the fixture into a fresh catalog, boots the team, delivers `task.md` to `doc.sup`, runs
to the supervisor's confirmation (or `max-timeout`), then runs the judges → verdict.

## The folder

| path | what it is |
| --- | --- |
| `docs.kdl` | the whole eval: the `doc` team (sup + writer) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the documentation request delivered to `doc.sup` |
| `fixture/` | the pre-built world, copied 1:1: `worker/` (the `checkout` repo, green suite, stub README, owner-pinned author `doc.writer`, git db `worker/_git` → `.git` on copy) and `sup/` (coordinate-only, no repo). Each holds an `st2`-native persona. |
| `judges/` | the held-out judges (below) |

## What makes it pass (all judges must pass — the team never sees these)

- **isolation + docs lane** (`judges/isolation.sh`) — only `doc.writer` authored; sup owns no repo; **`src/`
  is byte-identical** to base (docs-only, behavior unchanged).
- **visible suite** (`judges/suite.sh`) — `node --test` green on HEAD.
- **docs written** (`judges/docs-written.sh`) — the stub README is meaningfully expanded (≥25 lines) with a
  worked example.
- **completeness signals** (`judges/completeness.sh`) — non-gating keyword proxies for the 3 contracts +
  return shape (the cold reader is definitive).
- **COLD READER** (`judges/cold-reader.sh`) — **the discriminator**: a fresh `claude --print` agent gets
  ONLY the docs + the library as a mangled black box + a task in human terms, and must compute
  `totalCents === 1944`. Good docs → the reader succeeds; a missing contract → silently wrong.
