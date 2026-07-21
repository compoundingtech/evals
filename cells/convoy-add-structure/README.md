# convoy-add-structure — add + render produce the redesign overlay

**Discriminates:** does the real `convoy add --dir <repo>` followed by `convoy render <id>` produce the redesign
workspace overlay — the rig under `.convoy/`, the `.claude/rules/` loader, a pristine product-repo root, a
no-resume `pty.toml`? (deterministic, held-out)

**Capabilities required:** `convoy,st,pty,git` · run `bin/evals preflight`. No LLM — real command, assert exact shape.

## What it proves (Nathan ask)

Prove `convoy add` produces the structure we *think*. Per the redesign
([`cos notes/convoy-structure-redesign.md`](https://github.com/compoundingtech/cos/blob/main/notes/convoy-structure-redesign.md)):
the workspace overlay moves **out of the repo root into `.convoy/`** (`PERSONA.md` + `DING-BUS.md` + `pty.toml`),
plus `.claude/settings.local.json`, **all git-excluded** so the product-repo root stays **pristine**; the bus folder
is `<net>/smalltalk/<shorthost>.<identity>/` with `inbox/` + `archive/` + `status`; and `pty.toml` carries **no
`--resume`** (a launch spec, not a conversation-resume).

CI/regression guard for that shape (complementary to `convoy doctor`).

### Stage scope

convoy is **declarative**: `add` **declares** (writes `<net>/catalog/<id>.toml`, nothing else), `render`
**materializes** the workspace overlay, `up` **reconciles and launches**. This cell covers **add + render** — both
deterministic, no model invoked, nothing spent.

The **bus folder is created by `up`**, not by add or render (`render` reports *"launched NO pty, touched NO bus"*).
Grading it here would fail a correct system for not doing something it was never asked to do, so it is a **SKIP with
its owning stage named**, never a FAIL. `up` coverage lives in `convoy-network` and the `convoy-doctor-*` cells.

`render` resolves the claude-code hook scripts through `SMALLTALK_DIR`, then an `st` on `PATH`. With **neither**, it
aborts after writing only a **partial** overlay (no `pty.toml`, no `settings.local.json`). That is a missing
dependency, not a convoy defect — the probe records it in `render.out` and warns.

## How it works (box-free)

- `fixture/probe.sh` — `convoy init` an isolated net, `convoy add` into a throwaway repo, `convoy render` to
  materialize, capture the overlay shape + `git status --porcelain`, then tear down. `<shorthost>` is derived
  portably (short hostname, lowercased — convoy's `shortHostname`), never hardcoded.
  The seed commit runs with `core.hooksPath=` so an **operator's** global git hooks (e.g. a commit-msg identity
  guard that rejects the fixture's `as-agent@eval.local` author) cannot kill it. If the seed does not land, the
  repo has **no baseline**, every fixture file reads as dirt, and the pristine-root gate blames convoy for a
  `CLAUDE.md` this script wrote. The probe now fails loudly on that instead.
- `fixture/grade.sh` — hard gates: **OVERLAY-IN-.convoy**, **PRISTINE-ROOT**, **NO --resume**, **LOADER**,
  **MUTATION-VALID**; **BUS-FOLDER** is stage-scoped (SKIP, owned by `up`). The `CLAUDE.local.md` exact location (root vs `.claude/`) is **held** pending
  convoy-claude — presence + pristine-root are asserted now; the exact-path gate lands once it's decided.

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/evals run convoy-add-structure`. Greenfield-safe;
zero-orphan teardown; never touches the live convoy.

See `task.toml` for the full spec. Sibling: [`convoy-init-structure`](../convoy-init-structure/README.md) (the
network layout). Coordinate the exact target + per-piece landings with convoy-claude.
