# team-standup — a supervisor stands up the seat the work needs

**Discriminates:** can a supervisor turn **one instruction into a team**? Every other team cell declares
every seat it uses, so "coordination" is graded over a team the fixture already built. Here exactly one seat
is declared and the work needs two: the specialist that owns `widget` **does not exist** when the run
starts, and nothing but `ts.cos` can bring it into being. A passing verdict therefore cannot be explained by
a pre-built team.

**Run it:** `st2 eval ./cells/team-standup/`

## Cost — read this before running it

**Two Claude seats, `claude-sonnet-5` at medium effort, `1800s` cap.** One is declared (`ts.cos`); the second
is spawned during the run and is the point of the cell. `CATALOG.md` is derived from declared seats, so its
row reads `1` seat / `low` — for this cell that is the floor, not the estimate. Budget it as a two-seat
`medium` cell.

The runtime seat is pinned to the same model and effort as the declared one, in both the launch line and
`fixture/cos/PERSONA.md`. `bin/check-model-policy.sh` reads one line at a time and cannot tell the nested
launch from the outer one, so that pin is asserted by review here rather than by the gate.

## The folder

| path | what it is |
| --- | --- |
| `team-standup.kdl` | the whole eval: the `ts` team (the supervisor **only**) + the `eval {}` block |
| `task.md` | the single seeded request delivered to `ts.cos` |
| `fixture/` | `cos/` (coordinate-only, **not** a repo) and `widget/` (the repo with no owner: `SPEC.md`, a throwing stub, a visible suite, git db `widget/_git` → `.git` on copy). Each holds its st2-native persona, loader, and canonical hooks — including `widget/`, because the seat that gets stood up is a real Claude seat and its harness has to be in the fixture too. |
| `judges/` | the held-out bash judges (below) |

`widget/_git` pins `core.hooksPath` at an empty in-repo directory: a machine-global hook path would
otherwise refuse or rewrite the very commit this cell grades.

## What makes it pass (all judges must pass — the team never sees these)

- **standup** (`judges/standup.sh`) — a bus identity beyond `ts.cos`/`requester` sent mail, **and** a
  harness session beyond the declared seat exists in the eval's pty registry. Both halves gate, because
  either alone is forgeable: `st2 message send --as` can fake a voice with no seat behind it, and a bare
  `sleep` session is a process with nothing to say.
- **task correct** (`judges/task-correct.sh`) — the visible suite is green and `wordCount` behaves on cases
  it never covers (empty, all-whitespace, tabs, newlines, leading/trailing runs). Behavior only: any correct
  implementation passes.
- **isolation** (`judges/isolation.sh`) — the work is a commit beyond the seed, the tree is clean, no
  foreign author, and the supervisor's directory is still not a repo. The widget repo's identity is pinned
  to `ts.dev`, so authorship cannot distinguish who typed it — that is what **standup** is for.
- **coordination** (`judges/coordination.sh`) — delegation to the seated specialist, its report back, and
  the supervisor's single confirmation to `requester` are all visible on the bus.

`supervise` is required and not for respawn: teardown reconciles **declared** seats, so without it the seat
the supervisor spawned would outlive the run. It lives in the hermetic `PTY_ROOT`, so the sweep finds it.

## Evidence

**Not yet run against models** — it is proposed, not recorded, and `CATALOG.md` shows no model evidence for
it. What has been exercised is the grading: all four judges were run against a simulated post-run catalog —
bus mail, a hydrated widget repo, and pty sessions — in a correct arrangement and five wrong ones. Each
failure mode fails exactly the judges it should:

| Simulated outcome | Judges that fail |
|---|---|
| the supervisor did everything itself, no second seat | `standup`, `coordination` |
| the supervisor faked the specialist's voice with `--as`, no seat | `standup` |
| the specialist reported nothing back | `standup`, `coordination` |
| nothing was committed | `task correct`, `isolation` |
| a plausible but wrong implementation (`split(" ")`) | `task correct` |

## Lineage

A `team-standup` cell existed before the native-st2 rewrite and was retired with it, because it stood its
specialist up through the old agent-rendering and one-shot host generators — surfaces
`bin/check-retired-surfaces.sh` now rejects outright. The discriminator was never the problem; the mechanism
was. This one seats the specialist through the documented `st2 pty run` launch path instead, so it is
expressible in the current runtime.
