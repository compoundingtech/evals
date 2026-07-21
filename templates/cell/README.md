<!-- TEMPLATE — copy to cells/<name>/README.md and fill in. Delete this comment. -->
# Cell — TODO(name)

**Discriminator.** TODO(one sentence: the specific behavior this cell catches that no other cell does —
this is the row you add to `REGISTRY.md`).

## What it proves

TODO(2–3 sentences, plainer than task.toml's `evaluates`: what claim about the *system* this stresses,
and the failure-that-looks-like-success it rules out).

## Run it

```sh
# team cell (real agents, isolated convoy net):
bin/evals run <name>            # ensures pinned personas, then fixture/spin.sh
# ...observe the loop settle (or, once convoy eval lands, wait for the completion event)...
cells/<name>/fixture/grade.sh "$EVAL_SANDBOX/<name>"   # the held-out judge
bin/evals teardown "$EVAL_SANDBOX/<name>"              # reap sessions + neuter pty.toml

# deterministic / probe cell (no live team): probe then grade
cells/<name>/fixture/probe.sh "$SB" && cells/<name>/fixture/grade.sh "$SB"
```

## Env it needs

TODO(list the vars from framework.md this cell requires — commonly `PERSONAS_DIR`; team cells self-isolate
their own `ST_ROOT`/network via spin.sh so you usually need nothing else). Never set `ST_AGENT` for the runner.

## Caps

TODO(the `caps` from your `cells.manifest` row, and why each is needed — e.g. `st,pty,convoy,git,claude`).
