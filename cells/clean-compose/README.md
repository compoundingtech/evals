# clean-compose — no-repo-pollution cell

**Discriminates:** does `convoy add --dir <repo>` compose an agent into an existing git repo **without polluting
its working tree** — `git status --porcelain` stays EMPTY? (deterministic, held-out)

**Capabilities required:** `convoy,st,pty,git` · run `bin/st-evals preflight` to confirm. No LLM — this cell
grades which files convoy wrote, not any agent behavior.

## What it proves (Nathan's mandate)

*"We can work in convoy without polluting the repo."* When convoy composes an agent into a real product repo it
writes its rig — `CLAUDE.local.md`, `PERSONA.md`, `DING-BUS.md`, `pty.toml`, `.claude/settings.local.json` — into
that repo. Every one of those must be excluded (via `.git/info/exclude`) so it never shows up in the developer's
`git status` or risks an accidental commit.

convoy *used to* leak `pty.toml` + `.claude/settings.local.json` (it excluded only the first three). **convoy #51**
(`a609204`, "clean worktree") started excluding the rig files but missed those two; **convoy #53** (`c9a5dcb`)
completes it — adds both to the repo's own `.git/info/exclude` (host-independent). This cell is the held-out,
deterministic **regression guard**: run against a pre-#53 convoy it goes **RED** on `?? pty.toml` (witnessed on
the real binary before the fix); against convoy `>= c9a5dcb` (#53) it is **GREEN**. It goes RED the moment a
convoy-authored file stops self-excluding — the exact regression class #53 fixes. **Requires convoy `>= c9a5dcb`**
(`probe.sh` records the convoy version it ran against).

## How it works (box-free)

- `fixture/setup-sandbox.sh` — a throwaway repo with its own `CLAUDE.md` + a project skill, committed **clean**.
- `fixture/probe.sh` — `convoy init` an isolated net (short `/tmp` path — the pty socket path is ~90-byte
  limited), `convoy add` an agent **into the repo**, capture `git status --porcelain`, run a **synthetic-dirt
  mutation check** (plant a file → porcelain must go non-empty → remove), then `convoy down --force`.
- `fixture/grade.sh` — hard gates: **CLEAN-COMPOSE** (porcelain empty), **MUTATION-VALID** (planted dirt is
  detected → the gate has teeth), **ISOLATION** (no session leaks to the operator's global pty/convoy root).

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/st-evals run clean-compose`. Self-isolating +
zero-orphan teardown; nothing touches the live convoy.

## Grading

See `task.toml` `[grader]`. A false PASS is impossible without tripping MUTATION-VALID: if the porcelain check were
broken (always empty), the planted dirt would go undetected and the cell FAILS. A leak names the offending files
(the `pty.toml` / `.claude/settings.local.json` gap that convoy #53 closed).

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md). Sibling:
[`compose-config-load`](../compose-config-load/README.md) proves the composed repo's `CLAUDE.md` + skills still
**load and work** through the compose.
