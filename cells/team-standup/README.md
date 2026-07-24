# team-standup — team-formation cell

**Discriminates:** can a stood-up chief-of-staff stand up a *working* specialist that takes a real delegated task end-to-end? — delegate → execute-in-its-own-repo → report → the CoS walks it read-only and confirms. Onboarding proves the manager; this proves the manager can build a team.

**Capabilities required:** `claude,st,pty,git,node`

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/team-standup/
```

`team-standup.kdl` is the whole eval. It copies the fixture (the CoS `ts.cos`'s persona + the `taskflow` product
repo, `_git`→`.git` on copy) and boots the CoS, then delivers the seeded task. The CoS **stands up the specialist
itself at runtime** — it runs `st2 render-agent --identity taskflow-dev --dir "$CATALOG/taskflow" --persona … --supervisor "$ST_AGENT" "$CATALOG"`
then `st2 up --once "$CATALOG"` — briefs it over the bus, and walks the result read-only. The `supervise` directive
reaps the runtime-spawned specialist at teardown (zero orphans). Four held-out `judges/`: standup (the specialist's
busdir exists), isolation, task-correct (a mutation-valid `completeTask` fix), coordination. Hermetic catalog;
nothing touches your live network. Caps: `claude,st,pty,git,node`.

The eval boots the CoS unattended via its `.kdl` `command`; `st2 render-agent` installs the runtime-spawned
specialist's persona overlay + boot hooks (workspace-local, git-excluded) into `$CATALOG/taskflow`, and `st2 up
--once` brings it online. The ding sidecars carry the wakes over the smalltalk bus.

## Grading

- **Held-out judges** (`judges/`): the specialist authored the only commit (isolation from git metadata); `completeTask(id)` actually **behaves** (an independent probe: known id → task marked done; unknown id → throws); the regression test is **mutation-valid** (red on the base src, green on the fix). None of this is gameable by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** the specialist changes only the `taskflow` repo it owns; the CoS owns none (its dir is not a git repo) and coordinates only over the bus. A CoS commit or out-of-band coordination fails the run outright.
- **What's really under test is the loop**, not the (trivial) code: did the CoS *delegate* rather than do the work, did the specialist stay in its lane and walk its own diff, and did the CoS *verify* (re-run the tests) rather than rubber-stamp?

See `team-standup.kdl` + `judges/` for the full spec.
