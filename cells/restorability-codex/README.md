# restorability-codex — restore-WITHOUT-resume, Codex-native (the twin)

**Discriminates:** does a **Codex** agent cold-restarted with **NO `--resume`/`--session-id`** reconstruct its
working state from `now.md` — via the **codex** SessionStart hook (smalltalk **PR #86**) — the same way the claude
cell proves for Claude? (held-out)

**Capabilities required:** `codex,st,pty,git` + **`jq`** (the codex hook hard-deps jq) · run `bin/st-evals
preflight` to confirm.

## What it proves (the cross-family leg of Nathan's mandate)

The [claude cell](../restorability/README.md) proves an agent restores without `--resume` and does not inherit a
stuck queue. This twin proves the **now.md restore parity for Codex** — because Codex's SessionStart hook mechanism
is **different** (a JSON payload on **stdout**, `.additionalContext`, not the claude hook's stderr + exit 2), so
parity is **not free** and must be proven. PR #86 makes the codex hook inject the **same** marker the claude hook
does — `<context source="st/context/now.md" agent="<id>">` — before the inbox snapshot.

Built **thin**: it reuses `restorability`'s convoy-reload + `now.md` reconstruct mechanism (= convoy `doctor` CHECK
4). The one twin-specific gate is asserting the **codex** hook's JSON payload. The stuck-queue discriminator is a
**claude CC-input-queue** concern and lives only in the claude cell; here `NO-QUEUE-CHANNEL` is the structural
corollary (a fresh codex session has no `--resume` channel), and the headline is the now.md restore parity.

## Two tiers

- **Deterministic core — `fixture/probe.sh` (box-free):**
  - **CODEX-HOOK-EMITS-BLOCK** (PR #86 parity): run the codex `session-start.sh` against the fixture `now.md`; jq
    `.additionalContext` must contain the marker + token. Negatives: **missing**/**stale** `now.md` (+ empty
    inbox) → no block. Skips-with-reason if `jq` is absent or the reference checkout predates #86.
  - **NO-RESUME** / **NO-QUEUE-CHANNEL**: the materialized codex `pty.toml` command carries no
    `--resume`/`--session-id` (a genuine cold boot; no restore channel).
- **Live headline — `fixture/spin.sh` (rides the box):**
  - **RECONSTRUCT**: a real cold-reloaded codex worker acts on `now.md` and writes `RECONSTRUCTED.log`, 0 rescues.

## Run it

`fixture/spin.sh` is self-isolating (`convoy init`s a scratch net + decoupled `PTY_ROOT`). You need `PERSONAS_DIR`
(runner-set) and `jq`. The codex hook is resolved portably from the `st` binary's real path (override with
`SMALLTALK_REPO`).

- Deterministic gates (no box): `fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`
- Full live run: `fixture/spin.sh`, or `bin/st-evals run restorability-codex`
- Grade: `fixture/grade.sh <SB>` · Tear down: `bin/st-evals teardown <SB>`

## Grading

See `task.toml` `[grader]`. **Dependency:** the CODEX-HOOK-EMITS-BLOCK gate requires the reference smalltalk
checkout `>= f782411` (#86) — **satisfied** at f8592ce; it correctly RED-flags an older checkout (a codex now.md
gap → sync the reference checkout). Requires `jq`.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading
model.
