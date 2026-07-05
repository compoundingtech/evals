# team-standup — team-formation cell

**Discriminates:** can a stood-up chief-of-staff stand up a *working* specialist that takes a real delegated task end-to-end? — delegate → execute-in-its-own-repo → report → the CoS walks it read-only and confirms. Onboarding proves the manager; this proves the manager can build a team.

**Capabilities required:** `claude,st,pty,git,node`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## Run it

Both the CoS **and** the specialist are launched via the real `st launch` (the same command that onboards a
chief-of-staff — the eval dogfoods the whole launch surface). `fixture/spin.sh` is **self-isolating** — it
creates and exports its own scratch bus root at `$SANDBOX/st-root`, so nothing touches your live network; the
st-launched CoS (and the worker it stands up) inherit that root by env inheritance. You need `PERSONAS_DIR`
(a checkout of the public personas repo — `bin/ensure-personas.sh` clones it pinned; the runner sets it) and
`ST_HOOKS_DIR` (your smalltalk `examples/claude-code/hooks` — used to pre-stage the *stood-up specialist's*
startup gates). No external `ST_ROOT` — spin owns the isolated root.

- `fixture/gate-p4.sh [SANDBOX]` — **P4**, the standup *mechanics*, hermetic + offline (exit 0 = PASS): `st launch --dry-run` writes the child's identity + wires the boot hook; the CoS records the specialist in `team.md`.
- `fixture/spin.sh [SANDBOX]` — **P5**, the LIVE proof: `st launch`es the CoS (`--unattended`, collision-proof stev session name so it can't clobber a live `cos`); the CoS reads the seeded task, **stands up `taskflow-dev` itself** via `st launch`, briefs it over the bus, and walks the result. Or: `bin/st-evals run team-standup`.
- `fixture/grade.sh [SANDBOX]` — ground-truth grade once the loop closes. Tear down after with `bin/st-evals teardown <SANDBOX>`.

`st launch --unattended` auto-dismisses the CoS's startup gates (dev-channels / folder-trust / MCP-enable). The specialist the CoS stands up gets its folder-trust + project-MCP pre-staged by `spin.sh` (st launch installs its persona + boot hooks). asyncRewake carries the wakes; poke by hand only if an agent idles on a delivered message (the pty session name differs from the coord identity — see the notes `spin.sh` prints).

## Grading

- **Held-out acceptance** (`task.toml` `[grader]`): the specialist authored the only commit (isolation from git metadata); `completeTask(id)` actually **behaves** (an independent probe: known id → task marked done; unknown id → throws); the regression test is **mutation-valid** (red on the base src, green on the fix). None of this is gameable by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** the specialist changes only the `taskflow` repo it owns; the CoS owns none (its dir is not a git repo) and coordinates only over the bus. A CoS commit or out-of-band coordination fails the run outright.
- **What's really under test is the loop**, not the (trivial) code: did the CoS *delegate* rather than do the work, did the specialist stay in its lane and walk its own diff, and did the CoS *verify* (re-run the tests) rather than rubber-stamp?

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
