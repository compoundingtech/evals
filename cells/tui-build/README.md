# tui-build — greenfield-build cell

**Discriminates:** a team builds a real terminal UI over the agent network — two views sharing one data layer — and does a **human-centered usability find→fix pass**. "It renders the mock" is table stakes; "it's usable on the real network" is the bar.

**Capabilities required:** `claude,st,pty,git,node`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## Run it

Point `ST_ROOT` at a scratch coordination bus, `ST_HOOKS_DIR` at your smalltalk `examples/claude-code/hooks`,
and `PERSONAS_DIR` at a checkout of the public personas repo (`bin/ensure-personas.sh` clones it pinned).

- `fixture/setup-sandbox.sh [SANDBOX]` — seed the `agent-viz` repo from the bundled prototypes (bare origin + one clone per agent, distinct authors) + materialize the frozen synthetic network.
- `fixture/spin.sh [SANDBOX]` — compose the 4 personas, wire them (asyncRewake + pre-trust), seed the build request into `tui-sup`'s inbox, launch the team (`tui-sup` integration lead + `tui-tree`/`tui-cards` view specialists + `tui-ux` usability reviewer).
- `fixture/grade.sh [SANDBOX]` — mechanical gates (isolation + suite-green + wired-to-real-data + status-coverage) + render/usability pointers.

**Two roots (don't conflate):** `ST_ROOT` here is the **coordination bus** (where the team talks). The built viz reads its **data** from the **frozen fixture** — `ST_ROOT=<sandbox>/fixture/smalltalk` — a separate root the personas pass explicitly. The frozen fixture is what makes tests + grading reproducible.

**Launch tax:** with an older `st launch`, each agent boots into the dev-channels confirmation gate (press Enter); the hands-off `st launch` (unattended mode) dismisses it. asyncRewake carries the wakes; poke by hand only if an agent idles on a delivered message.

## Grading

- **Held-out acceptance:** (1) **cold-navigation** — render both built views against the frozen fixture; a fresh reader must be able to tell who's around, who has unread, and read the selected agent's latest message. (2) the **usability find→fix rubric** (`fixture/usability-rubric.md`) — the team never sees it; a cross-family judge is preferred (a Claude judge inflates Claude work). The fixture deliberately plants the edge cases (an `away` status the seed type omits, an overflow inbox, empty states, a stale `unknown`).
- **Isolation is a hard PASS/FAIL gate:** each agent's commits stay in its own module's lane; `tui-ux` writes no code; a usability fix is authored by the module's owner. A cross-lane change fails the run.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
