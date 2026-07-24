# hook-integrity — does your Claude Code SessionStart hook actually FIRE?

**Discriminates:** a Claude agent's **SessionStart hook FIRING** (proven from ground truth) vs merely
being *configured*. Reading `settings.local.json` proves configuration — which was already true in the
field case this comes from, where hooks were configured but silently never ran. This proves execution.

**Capabilities required:** `claude,st,pty,git`

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/hook-integrity/     # render the REAL hook into 2 legs → seed now.md → boot ON + hooks-disabled OFF → judge
```

The whole eval is `hook-integrity.kdl`. `fixture/setup.sh` runs as the eval's `run "setup"` (before boot):
it `st2 render-agent`s the **real** SessionStart hook (smalltalk `session-start.sh`) into two identical workspaces
(`repo-on`, `repo-off`), seeds the **same** per-run secret token into each leg's `context/now.md`, and adds a
**parallel SessionStart witness hook** alongside the real one. Two team agents boot identically **except** `hi.off`
adds `--settings disableAllHooks` (claude 2.1.x dropped the old `--no-hooks`), which co-suppresses both hooks.

## What it proves — the drift-proof core

The SessionStart hook injects your agent's durable working-state (`context/now.md`) on its first turn —
**only if it fires**. Asserting on what the *model* then does is fragile: a modern claude agent, told to
"act on your durable working state," fetches `now.md` itself via `st context read` (a **non-hook** path),
so the token reaches it either way. So the discriminator asserts a **hook side-effect** the model can't forge:

1. `now.md` is seeded with a **secret token** generated fresh this run — reachable no other way (not the
   persona, not the repo, not the kick).
2. A **parallel SessionStart witness hook** (`hook-witness.sh`) is configured alongside the real
   `session-start.sh` in **both** legs. When SessionStart fires, the witness records what the hook injects
   (`now.md`, verbatim) to `$CATALOG/hook-witness/<id>.injected`. It fires **iff** SessionStart fires — i.e.
   iff the real hook fires — and it is a file the model **cannot create**.
3. Two legs, identical except one flag:
   - **hooks ON** (`hi.on`, plain `exec claude`) → SessionStart fires → witness present, carrying the token. ✅
   - **hooks OFF** (`hi.off`, `exec claude --settings '{"disableAllHooks":true}'`) → both hooks co-suppressed
     → **no witness**, even though the agent can still read `now.md` via `st context read`. ❌
4. **PASS iff the witness is present (with the real token) on ON and absent on OFF.** Zero model-behavior
   dependence, content-verified against the per-run token, immune to the `st context read` drift that
   defeated the older `HOOK_OK.txt` control. The real `session-start.sh` is left **unmodified** — the witness
   only *observes* its firing.

The probe agent runs a **minimal standalone persona** that never mentions `now.md` or the token — but the
proof no longer rests on the agent at all; it rests on the hook's own witness.

## Isolation + safety

A two-agent team `hi` (`hi.on` + `hi.off`), no coordination (this tests hook plumbing). Each leg is a hermetic
catalog workspace — your live network is never touched. Sessions are torn down **zero-orphan** (agents + any
sidecars). If the agent commits, isolation attributes it (author-pinned to `hi-agent`).

## Grading (held-out judges in `judges/`)

- **HOOKS-ON FIRED (hard):** `$CATALOG/hook-witness/hi.on.injected` exists and contains the run's `REHYDRATE-<token>` → the SessionStart hook fired and emitted the real `now.md` (proven from a side-effect, not model output).
- **HOOKS-OFF CONTROL (hard, drift-proof):** `$CATALOG/hook-witness/hi.off.injected` is absent/tokenless → with `disableAllHooks` the hook did not fire. The witness is a hook side-effect the model can't forge, so the OFF-leg agent reaching `now.md` via `st context read` does not create it.
- **HOOK-EXCLUSIVE (attribution):** the token appears in **no agent seed input** — persona, kick, repo-seed, inbox — only in `context/now.md`. The hook's own outputs (the witness, the model's `HOOK_OK.txt`, its bus report) legitimately carry it and are excluded.

## Scope

**v1 (this cell): the SessionStart leg** — deterministic, fires on every launch, load-bearing for the
boot ritual + restart-continuity rehydrate. **v2 (planned):** StopFailure (status flip + ding on an
API error) and PreCompact (now.md flush on compaction) — both need a deterministic fault trigger
(likely a smalltalk-side mock); see the design notes.
