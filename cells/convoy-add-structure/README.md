# convoy-add-structure — convoy add produces the redesign overlay

**Discriminates:** does the real `convoy add --dir <repo>` produce the redesign workspace overlay + bus folder —
the rig under `.convoy/`, a pristine product-repo root, a host-prefixed `smalltalk/` bus folder, a no-resume
`pty.toml`? (deterministic, held-out)

**Capabilities required:** `convoy,st,pty,git` · run `bin/st-evals preflight`. No LLM — real command, assert exact shape.

## What it proves (Nathan ask)

Prove `convoy add` produces the structure we *think*. Per the redesign
([`cos notes/convoy-structure-redesign.md`](https://github.com/myobie/cos/blob/main/notes/convoy-structure-redesign.md)):
the workspace overlay moves **out of the repo root into `.convoy/`** (`PERSONA.md` + `DING-BUS.md` + `pty.toml`),
plus `.claude/settings.local.json`, **all git-excluded** so the product-repo root stays **pristine**; the bus folder
is `<net>/smalltalk/<shorthost>.<identity>/` with `inbox/` + `archive/` + `status`; and `pty.toml` carries **no
`--resume`** (a launch spec, not a conversation-resume).

CI/regression guard for that shape (complementary to `convoy doctor`). **RED** until pieces #1 (`.convoy/` overlay)
+ #3 (`smalltalk/` split + host-prefix) land; **GREEN** after; RED again on any regression.

## How it works (box-free)

- `fixture/probe.sh` — `convoy init` an isolated net, `convoy add` into a throwaway repo, capture the overlay +
  bus-folder shape + `git status --porcelain`, then tear down. `<shorthost>` is derived portably (short hostname,
  lowercased — convoy's `shortHostname`), never hardcoded.
- `fixture/grade.sh` — hard gates: **OVERLAY-IN-.convoy**, **PRISTINE-ROOT**, **BUS-FOLDER** (+ inbox/archive/status),
  **NO --resume**, **MUTATION-VALID**. The `CLAUDE.local.md` exact location (root vs `.claude/`) is **held** pending
  convoy-claude — presence + pristine-root are asserted now; the exact-path gate lands once it's decided.

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/st-evals run convoy-add-structure`. Greenfield-safe;
zero-orphan teardown; never touches the live convoy.

See `task.toml` for the full spec. Sibling: [`convoy-init-structure`](../convoy-init-structure/README.md) (the
network layout). Coordinate the exact target + per-piece landings with convoy-claude.
