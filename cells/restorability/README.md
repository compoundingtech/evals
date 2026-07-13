# restorability — restore-WITHOUT-resume cell

**Discriminates:** does an agent cold-restarted with **NO `--resume`/`--session-id`** come back **functional** —
reconstructing its working state purely from externalized durable substrate (`now.md` via the SessionStart hook +
git + bus) — **and** without inheriting stale session state (a stuck CC input-queue) the way a `--resume` restore
does? (held-out)

**Capabilities required:** `claude,st,pty,git` · run `bin/st-evals preflight` to confirm your setup supports this
cell. The codex twin (`restorability-codex`) needs `codex` + `jq`.

## What it proves (Nathan's mandate: agents *don't use* resume AND *don't need* it)

The reboot default is being moved **off** session-preservation (`--resume`). A real incident showed why: a
`--resume` respawn **restored a stuck Claude Code input-queue** (a pending keystroke that kept replaying after its
message was archived), so the agent came back but wedged. `convoy reload` respawns from the stored `pty.toml`
command — **no `--resume`/`--session-id`, fresh transcript** — so the only way state survives is externalization.

This cell is built **thin**: it **reuses** convoy `doctor` CHECK 4's convoy-reload + SessionStart reconstruct
mechanism (the "restartability thesis"), and adds the two **held-out incident gates doctor lacks**:

1. **NO-STUCK-QUEUE-inheritance** + a matched **`--resume` control** that shows the state *would* survive with
   resume — the discriminator proves the difference is **real**, not mere absence.
2. **The codex twin** (`restorability-codex`) — proves the codex SessionStart `now.md` injection (smalltalk
   **PR #86**) works fleet-wide, not just for claude.

That trio *is* the mandate's proof.

> **Honest framing (cos-approved) — read this before the stuck-queue gate.** The no-stuck-queue property is proven
> **STRUCTURALLY**: a `convoy reload` severs every prior-session restore channel (no `--resume`, no
> `--session-id`, fresh transcript), and the incident's input-queue lives in exactly that `--resume`-restored
> session state — so a fresh session has **no channel** to inherit it. The transcript-codeword discriminator is a
> **DOCUMENTED PROXY** on that same restore-channel property; **it is NOT the real CC input-queue.** The real
> queue is *deliberately not seeded* because its persistence is undocumented / version-dependent / buggy, and a
> fragile hand-authored-JSONL seed would risk a **false PASS** on a CC version bump (the worse-than-FAIL case).

## Two tiers (mirrors resumability + restart-continuity)

- **Deterministic core — `fixture/probe.sh` (box-free; needs no live model):**
  - **NO-RESUME** — materialize the real `pty.toml` (what `convoy reload` respawns from) and prove the stored
    command carries no `--resume`/`--session-id` (a genuine cold boot).
  - **NO-QUEUE-CHANNEL** — the structural corollary: a fresh session has no channel for a stuck queue to carry.
  - **HOOK-EMITS-BLOCK** (correction #1 STRONGER) — run the claude SessionStart hook against the fixture `now.md`
    and prove it emits the `<context source="st/context/now.md" agent="rl-wk">` block containing the token; plus
    the negatives (**missing** `now.md` → no block = context lost; **stale** `now.md` → no block).
- **Live headline — `fixture/spin.sh` (rides the box):**
  - **RECONSTRUCT** — a real cold-reloaded worker acts on `now.md` and writes `RECONSTRUCTED.log`, 0 rescues.
  - **DISCRIMINATOR** — `fixture/discriminator.sh`: a codeword planted by claude's own transcript write is recalled
    under `--resume` (detection proof) and shed under a fresh session (shed proof). Gated: **skips-with-reason** if
    codeword-recall can't be established (CC-version drift), so the cell degrades gracefully.

## Run it

`fixture/spin.sh` is **self-isolating** — it `convoy init`s a scratch net at `$SB/net` and a decoupled short
`PTY_ROOT`, so nothing touches your live network. You only need `PERSONAS_DIR` (the runner sets it via
`bin/ensure-personas.sh`). The SessionStart hook is resolved portably from the `st` binary's real path (override
with `SMALLTALK_REPO`).

- Deterministic gates (no box): `fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`
- Full live run: `fixture/spin.sh` (auto-materializes the sandbox), or `bin/st-evals run restorability`
- Grade: `fixture/grade.sh <SB>` · Tear down (zero-orphan): `bin/st-evals teardown <SB>`

## Grading

See `task.toml` `[grader]`. **Hard, deterministic** gates: NO-RESUME, NO-QUEUE-CHANNEL, REHYDRATE-WIRED,
HOOK-EMITS-BLOCK (+ negatives). **Live headline** (rides the box): RECONSTRUCT + DISCRIMINATOR + ISOLATION (same
git author across the reload; nothing leaks to the operator's global pty root). A false PASS — a "reload" that
secretly resumed, reconstruction asserted without a real `now.md` injection, or a control that can't actually
detect the carried state — is worse than a FAIL.

**Dependency:** the codex twin's `now.md` gate requires the reference smalltalk checkout `>= f782411` (#86) —
**satisfied** at f8592ce; it correctly RED-flags an older checkout (the gate detecting the unsynced state *is* the
eval working).

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading
model.
