# evals as `type = batch` agent-specs — the st-eval format (phase-2)

Each eval is expressed as a `type = batch` agent-spec (KDL) that **wraps the cell's existing fixtures
byte-identical** and runs end-to-end via `st2 batch <catalog> <cell>`. The generator is `bin/gen-batch.sh`;
it edits NO fixture — it only declares a setup→run→grade DAG around the unchanged
`setup-sandbox.sh` / `compose-persona.sh` / `grade.sh` / `kick-*.md`.

## The honesty invariant (CoS phase-2 sample target)

Two facts, uniform for **every** wrapped cell, both inspectable in `bin/gen-batch.sh` and the per-cell fixtures:

1. **The grade stage shells the UNCHANGED held-out grader.** The generator emits, verbatim, the same for all cells:
   ```kdl
   stage "grade" { after "run"; exec { command "sh $CATALOG/scripts/grade.sh" }; verdict "grader-output" }
   ```
   where `$CATALOG/scripts/grade.sh` is a 2-line wrapper the generator writes:
   ```sh
   #!/usr/bin/env sh
   exec sh "<repo>/cells/<cell>/fixture/grade.sh" "$SB"     # the UNCHANGED repoint grader, byte-identical
   ```
   So the batch grades with the **exact same `cells/<cell>/fixture/grade.sh`** that graded the repoint gate —
   diff it against the gate to confirm zero edits. No inlined/edited grader anywhere.

2. **The verdict is `grader-output`** — the st2 executor parses the grader's `[PASS]`/`[FAIL]` OUTPUT
   (PASS iff ≥1 `[PASS]` & 0 `[FAIL]`), never the exit code. This is the same anti-hollow-green rule the
   repoint board used, and (per st2) `grader-output` cannot hollow-green an exit-0 grader.

## Spec shape (the whole DAG)

```kdl
agent "<cell>" {
  identity "<cell>"; host "<h>"; type "batch"
  run {
    seat "<seat-id>" { agent "<seat-id>" }        # one per extracted seat (sup + worker(s))
    kick      { to "<sup-id>"; from-file "$CATALOG/kick.md" }   # the cell's UNCHANGED kick-*.md
    done-when { grade; timeout "1200s" }          # GRADE-POLL: waits for the held-out grader to PASS
  }                                               #   (= the gate's poll-until-grade-green; ignores sup ack chatter)
  stage "setup" { exec { command "true" } }       # (world pre-built by the generator's dry-run; self-contained
  stage "run"   { after "setup"; run }            #   render-in-setup form is the follow-up polish)
  stage "grade" { after "run"; exec { command "sh $CATALOG/scripts/grade.sh" }; verdict "grader-output" }
}
```

`done-when { grade }` is the key faithfulness property: the run stage polls the held-out grader every ~3s
until it PASSES (or the 1200s timeout → honest FAIL graded on the final state). It waits for the **acceptance
criteria themselves**, exactly like the repoint gate's poll-until-0-FAIL — immune to a supervisor's
intermediate "received, delegated" acknowledgment.

## Path / naming (for the CoS diff)

- **Generator:** `bin/gen-batch.sh <cell> [--run]` — dry-run-extracts the cell's seats + kick from its OWN
  `spin.sh` (via `STEV_DRYRUN`, so `setup-sandbox.sh` + `compose-persona.sh` run byte-identical), renders the
  seats, authors the spec above.
- **Emitted spec path (per run):** `<catalog>/<host>/<cell>/agent.kdl`, where `<catalog>` is the cell's
  isolated sandbox `st-root`. Specs are regenerated per run (the durable artifacts are the generator + the
  unchanged fixtures, both committed); `gen-batch.sh <cell>` (no `--run`) emits + `st2 validate`s a spec in seconds.
- **Unchanged graders to diff vs the gate:** `cells/<cell>/fixture/grade.sh` (the generator never touches them).

## Proven

`license-mit` (generated) and `ghost-bug` (generated, grade-poll) both green live via `st2 batch`: 10 PASS /
0 FAIL / 0 WARN, real commits, held-out graders unchanged, `grader-output` verdict. Full fan-out board across
the st2-green team-loop cells: see the phase-2 board resource.
