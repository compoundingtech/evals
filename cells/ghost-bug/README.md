# ghost-bug — debug a subtle shared-default-mutation bug

**What it evaluates.** Real debugging, not symptom-patching. The `labelkit` library has a **ghost bug**:
`format()` does `Object.assign(defaultOptions, options)`, mutating the shared `defaultOptions` object — so
the first call with custom options permanently corrupts the defaults for every later call. The unit suite
is **green** (it never formats with defaults *after* a custom call), so the bug is latent. A supervisor
(`gb.sup`, coordinate-only) delegates to a specialist (`gb.fix`, owns the repo), who must **reproduce →
root-cause → fix (a non-mutating merge, not a band-aid) → add a mutation-valid regression test → commit**.

**Run it:** `st2 eval ./cells/ghost-bug/`

`st2 eval` copies the fixture into a fresh catalog, boots the team, delivers `task.md` to `gb.sup`, runs
to the supervisor's confirmation (or `max-timeout`), then runs the judges → verdict.

## The folder

| path | what it is |
| --- | --- |
| `ghost-bug.kdl` | the whole eval: the `gb` team (sup + fix) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the bug report delivered to `gb.sup` |
| `fixture/` | the pre-built world, copied 1:1: `worker/` (the labelkit repo with the ghost bug, **green** suite, base commit + owner-pinned author `gb.fix`, git db `worker/_git` → `.git` on copy) and `sup/` (coordinate-only, no repo). Each holds an `st2`-native persona. |
| `judges/` | the held-out bash judges (below) |

## What makes it pass (all judges must pass — the team never sees these)

- **isolation** (`judges/isolation.sh`) — only `gb.fix` authored commits (here the author **is** a gate —
  the repo identity is pinned); the supervisor owns no repo; the change stays in `src/test/package/README`.
- **visible suite** (`judges/suite.sh`) — `node --test` is green on HEAD (no deleting/weakening tests to pass).
- **root cause** (`judges/root-cause.sh`) — two probes **blind to how** it was fixed: the behavior probe
  (`format(custom)` then `format(default)` returns `[ b ]`) and the no-mutation probe (`defaultOptions` is
  UNCHANGED after a custom call). A freeze/reset band-aid fails these. Paper-over patterns are flagged as a WARN.
- **regression is mutation-valid** (`judges/regression.sh`) — **the integrity bar.** A test was added, and
  the team's HEAD tests **go RED when replayed against the original buggy BASE src** (checkout HEAD tree,
  overlay the buggy base `src/`, `node --test` must fail). A "regression test" green on the buggy base is
  theater. *This logic is ported verbatim from the held-out grader — do not soften it.*
- **coordination** (`judges/coordination.sh`) — the delegate → report loop is visible on the bus
  (`gb.sup → gb.fix` delegation, `gb.fix → gb.sup` report).
