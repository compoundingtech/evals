# test-writing — a regression-catching suite (mutation-scored)

**What it evaluates.** Whether a team can write tests that would **actually catch a regression**, not
coverage theater. The `grades` module has no tests; a supervisor (`tw.sup`, coordinate-only) delegates to a
specialist (`tw.dev`, owns the repo) to write a suite that pins the **exact** behavior — boundary cutoffs,
range edges, edge cases, error paths. It's a **test-writing lane** (`src/` must not change). The
discriminator is the **mutation score**: 12 planted mutants (boundary + aggregation changes to
`src/grades.js`) — a thorough suite kills them; a shallow "run each function once" suite survives them.

**Run it:** `st2 eval ./cells/test-writing/`

`st2 eval` copies the fixture into a fresh catalog, boots the team, delivers `task.md` to `tw.sup`, runs
to the supervisor's confirmation (or `max-timeout`), then runs the judges → verdict.

## The folder

| path | what it is |
| --- | --- |
| `test-writing.kdl` | the whole eval: the `tw` team (sup + dev) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the test-writing request delivered to `tw.sup` |
| `fixture/` | the pre-built world, copied 1:1: `worker/` (the `grades` repo — no tests yet, owner-pinned author `tw.dev`, git db `worker/_git` → `.git` on copy) and `sup/` (coordinate-only, no repo). Each holds an `st2`-native persona. |
| `judges/` | the held-out judges (below); `mutants.sh` is the grader-only mutant battery — **kept out of `fixture/`** so the team never sees the mutants |

## What makes it pass (all judges must pass — the team never sees these)

- **isolation + test-writing lane** (`judges/isolation.sh`) — only `tw.dev` authored; sup owns no repo;
  `src/` is byte-identical (they wrote tests, didn't change the code).
- **suite added + green** (`judges/tests-added-green.sh`) — a real suite (≥4 tests) that is green on the
  original code.
- **MUTATION SCORE** (`judges/mutation-score.sh`) — **the discriminator**: the suite kills **≥ 10 of 12**
  planted mutants (12 = perfect; 10–11 = strong-with-gaps; < 10 = coverage theater = FAIL).
