# Native Claude example ledger

This is the executable handoff for the maintained native-st2 Claude examples. The converted source and
free gates are pinned to immutable commit
[`4da1900e10ce42584f19b301df5ca44ca16e8938`](https://github.com/compoundingtech/evals/commit/4da1900e10ce42584f19b301df5ca44ca16e8938).
It deliberately covers two different workspace/persona shapes without starting a model:

| Example | Shape | Persona and render/reset mechanism |
|---|---|---|
| [`ding-reply.kdl`](https://github.com/compoundingtech/evals/blob/4da1900e10ce42584f19b301df5ca44ca16e8938/cells/ding-reply/ding-reply.kdl) | One Claude seat; exact threaded CLI reply; no MCP | The checked-in fixture already contains `work/CLAUDE.md` loading `@PERSONA.md`; `eval.copy` places that complete workspace in the fresh catalog. The hand-authored agent KDL uses one native bare `ding`. |
| [`signal-rename.kdl`](https://github.com/compoundingtech/evals/blob/4da1900e10ce42584f19b301df5ca44ca16e8938/cells/signal-rename/signal-rename.kdl) | Claude supervisor + three owned-package specialists; sequenced cross-package integration | `eval.copy` places the frozen graph and source personas in the fresh catalog; the pre-boot `materialize` run-step builds a catalog-local bare origin plus four clean clones and installs each clone's `CLAUDE.md` loading its `PERSONA.md`. The hand-authored KDL uses four native bare `ding` declarations. |

The folder-eval runner owns `ST_ROOT`, `PTY_ROOT`, and native ding lowering. Neither example authors a
bus root, a compatibility wake sidecar, or a retired render/add/build command. Their checked-in agent
KDL is the canonical source; the coordinated materializer creates only fixture workspaces and persona
overlays, not generated agent declarations.

## Free static acceptance

Run:

```sh
bin/check-claude-native.sh
bin/check-claude-reset.sh
bash -n cells/ding-reply/judges/*.sh \
  cells/signal-rename/judges/*.sh \
  cells/signal-rename/fixture/materialize.sh
```

The native gate rejects legacy bus/harness declarations, requires exactly one `exec claude` command,
one workspace, and one native bare `ding` per agent, and materializes dynamic fixtures before proving
every workspace has a non-empty `CLAUDE.md` loading a non-empty `PERSONA.md`.
Its immutable source is
[`check-claude-native.sh`](https://github.com/compoundingtech/evals/blob/4da1900e10ce42584f19b301df5ca44ca16e8938/bin/check-claude-native.sh).

The reset gate independently constructs two fresh copies of each fixture. It requires identical
Claude/persona/Git manifests, valid clean repositories, no checked-in live `.git`, and no absolute
origin outside the fresh catalog. `ding-reply` exercises the pre-seeded, non-Git path;
`signal-rename` exercises the dynamic, multi-clone Git path.
Its immutable source is
[`check-claude-reset.sh`](https://github.com/compoundingtech/evals/blob/4da1900e10ce42584f19b301df5ca44ca16e8938/bin/check-claude-reset.sh).

These checks are deterministic and do not invoke Claude or Codex. `st2 validate` validates a rendered
catalog, not a folder-eval KDL, so an opted-in `st2 eval` remains the authoritative KDL parse, native
ding, coordination, and judge proof.

## Run provenance and honest gap

- `ding-reply` historically scored **2/2 PASS** when it entered folder-eval form at
  [`7a063abfcc10b53a18d71bdabb0c478161694650`](https://github.com/compoundingtech/evals/commit/7a063abfcc10b53a18d71bdabb0c478161694650).
- `signal-rename` historically scored **6/6 PASS** when it entered folder-eval form at
  [`918ef31477596fc5008bf2335c922f3ac6f8e30f`](https://github.com/compoundingtech/evals/commit/918ef31477596fc5008bf2335c922f3ac6f8e30f).

Those historical runs used authored compatibility roots/sidecars. They are useful scenario and grader
provenance, but they are **not** current-native live proof. No model-backed rerun was authorized for
this conversion, so current-build runtime status is honestly **static gates PASS; live smoke pending
explicit authorization**.

`team-standup` remains a legacy reference to the retired dynamic `st2 render-agent` / `st2 up --once`
flow. It is not a current native example. This corpus also has no maintained Claude folder-eval
demonstrating a declarative `render {}` block; that is a separate support/example gap, not something
these two canonical hand-authored KDLs claim to cover.
