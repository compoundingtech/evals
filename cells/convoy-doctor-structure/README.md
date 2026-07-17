# convoy-doctor-structure — convoy doctor proves the redesign layout

**Discriminates:** does the narrated `convoy doctor` actually **prove** the network is laid out correctly — a
Structure section that PASSES on a well-formed net and **FAILS on a malformed one**? (deterministic, held-out)

**Capabilities required:** `claude,convoy,st,pty,git` · run `bin/st-evals preflight`. The structure half is no-LLM;
the `--full` can-work half rides the box (gated).

## What it proves (Nathan ask — the Johannes gate)

A green `convoy doctor` = a correctly-set-up, working convoy for a brand-new user. This cell guards that doctor
actually **proves** the redesign layout (not just narrates it) — the last mile that closes the whole
`init`→`doctor` deliverable (#1–#6) end-to-end on the acceptance gate (redesign #6, convoy #61).

## Two halves

- **STRUCTURE (deterministic, box-free):** `convoy doctor --quick --network <net>` (no agent spawn) emits the
  narrated **Structure** section — named network + `smalltalk/` + `pty/` + `worktrees/` + host-prefixed bus folders
  + pristine workspaces + cold-boot (no `--resume`). Asserts the section + all checks are narrated, all **pass on
  a well-formed net**, and — **mutation-valid** — doctor **flags a malformed net** (`worktrees/` removed → a ✗ +
  non-zero exit), proving the gate is real.
- **CAN-WORK (live, held/gated):** `convoy doctor --full` runs the real CoS→sup→worker graded org proof on the
  new-layout sandbox — the "and can do real work" half. It spawns real agents (heavy), so it's gated
  (skip-with-reason); the box-free structure half carries the layout proof.

## Critical isolation

doctor is scoped with **`--network <sandbox>`** and the ambient `ST_ROOT`/`PTY_ROOT`/`CONVOY_NETWORK` are **unset**
— a bare `convoy doctor` (or one relying on `ST_ROOT`) hits the operator's **real default network**. This cell
never touches the live fleet (verified: no doctor session leaks to the global pty root).

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/st-evals run convoy-doctor-structure`. The can-work
half runs via `fixture/spin.sh` (gated). Greenfield-safe; zero-orphan teardown.

See `task.toml` for the full spec. Siblings:
[`convoy-init-structure`](../convoy-init-structure/README.md) + [`convoy-init-narration`](../convoy-init-narration/README.md)
— the layout + init narration that doctor proves.
