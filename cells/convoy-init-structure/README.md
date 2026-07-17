# convoy-init-structure — convoy init produces the redesign layout

**Discriminates:** does the real `convoy init <net>` create the redesign network structure —
`<net>/{smalltalk,pty,worktrees}` + a recorded config? (deterministic, held-out)

**Capabilities required:** `convoy,st,pty,git` · run `bin/st-evals preflight`. No LLM — this cell runs the real
command and asserts the exact on-disk shape.

## What it proves (Nathan ask)

Prove our real tooling produces the structure we *think*. Per the redesign
([`cos notes/convoy-structure-redesign.md`](https://github.com/myobie/cos/blob/main/notes/convoy-structure-redesign.md)),
`convoy init` creates a named network directory with `smalltalk/` (synced bus state), `pty/` (machine-local pty
runtime), and `worktrees/` (the workspaces), plus a recorded network config so `add`/`up`/`doctor` stay consistent.

This is the **CI/regression guard** for that layout — complementary to `convoy doctor` (the user-facing setup
check). It is **RED** until the named-net + `smalltalk/pty/worktrees` pieces land, **GREEN** after, and RED again
the moment convoy regresses the shape.

## How it works (box-free)

- `fixture/probe.sh` — runs the real `convoy init` into an isolated short `/tmp` net, captures the tree + the
  presence of each required subdir + the config artifact, then tears the net down.
- `fixture/grade.sh` — hard gates: **STRUCTURE** (`smalltalk/`+`pty/`+`worktrees/` exist), **CONFIG RECORDED**,
  **MUTATION-VALID** (a bogus subdir reads absent → the presence check is non-vacuous).

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/st-evals run convoy-init-structure`. Greenfield-safe
(fresh isolated nets, zero-orphan teardown — never touches the live convoy).

See `task.toml` for the full spec. Sibling: [`convoy-add-structure`](../convoy-add-structure/README.md) (the
`.convoy/` workspace overlay + host-prefixed bus folder). Coordinate the exact target with convoy-claude as the
redesign pieces land.
