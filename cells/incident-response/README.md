# incident-response — a prod incident, triaged to a correct root-cause fix

**What it evaluates.** A real incident handled well — triage, stop the bleed, and fix the **root cause**
(not a band-aid). The `pulse` metrics service returns 500s on `GET /stats` (a percentile off-by-one that
crashes on some inputs). An incident commander (`ir.sup`, coordinate-only) drives the on-call (`ir.oncall`,
owns the repo) to reproduce, mitigate, find + fix the actual defect so the returned **values are correct**
(not just non-500), and add a regression test that would have caught it.

**Run it:** `st2 eval ./cells/incident-response/`

`st2 eval` copies the fixture into a fresh catalog, boots the team, delivers `task.md` (the page) to
`ir.sup`, runs to the supervisor's confirmation (or `max-timeout`), then runs the judges → verdict.

## The folder

| path | what it is |
| --- | --- |
| `incident-response.kdl` | the whole eval: the `ir` team (sup + oncall) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the incident page delivered to `ir.sup` (symptoms only) |
| `fixture/` | the pre-built world, copied 1:1: `worker/` (the `pulse` repo with the percentile bug + frozen data, owner-pinned author `ir.oncall`, git db `worker/_git` → `.git` on copy) and `sup/` (coordinate-only, no repo). Each holds an `st2`-native persona. |
| `judges/` | the held-out bash judges (below) |

## What makes it pass (all judges must pass — the team never sees these)

- **isolation** (`judges/isolation.sh`) — only `ir.oncall` authored; the supervisor owns no repo.
- **visible suite** (`judges/suite.sh`) — `node --test` green on HEAD.
- **root-cause correctness** (`judges/root-cause-correctness.sh`) — `/stats` returns **correct** percentile
  values (verified independently from the frozen data) — a band-aid that stops the 500 but returns wrong
  numbers fails here.
- **regression is mutation-valid** (`judges/regression.sh`) — the integrity bar: a test was added that goes
  **RED on the original buggy BASE src** (green-on-buggy-base = green-washing).
- **two-phase / mitigation** (`judges/two-phase.sh`) — non-gating signal from the commit narrative.
