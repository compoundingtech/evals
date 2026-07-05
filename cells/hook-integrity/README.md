# hook-integrity — does your Claude Code SessionStart hook actually FIRE?

**Discriminates:** a Claude agent's **SessionStart hook FIRING** (proven from ground truth) vs merely
being *configured*. Reading `settings.local.json` proves configuration — which was already true in the
field case this comes from, where hooks were configured but silently never ran. This proves execution.

**Capabilities required:** `claude,st,pty,git`  ·  run `bin/st-evals preflight` to confirm your setup.

## Run it (one command)

```
bin/st-evals run hook-integrity
```

It prints a **loud PASS / FAIL banner**. `PASS` = your SessionStart hook fires and rehydrates
`context/now.md` on launch. `FAIL` = it didn't (the silent-hook failure mode) — with a specific
reason + a fix pointer. Takes ~2–3 min on a healthy machine; up to ~4 min if the hook is genuinely
dead (it waits to be sure it isn't just a slow agent). Env knobs: `HI_TIMEOUT` (default 240s),
`HI_GRACE` (45s). Direct form: `cells/hook-integrity/fixture/run.sh`.

## What it proves — the ungameable core

The SessionStart hook injects your agent's durable working-state (`context/now.md`) as a `<context>`
block on its first turn — **only if it fires**. The diagnostic exploits that:

1. It seeds `now.md` with a **secret token** generated fresh this run — reachable **no other way**:
   not in the agent's persona, not in its repo, not in its inbox. `now.md` tells the agent to write
   `REHYDRATE-<token>` into `HOOK_OK.txt`.
2. It launches the agent **twice**, identical except one flag:
   - **hooks ON** (`st launch claude`) → if the hook fires, the agent sees the token and writes it. ✅
   - **hooks OFF** (`st launch claude --no-hooks`, MCP still on) → the negative control. No hook, no
     injection, no token. ❌
3. **PASS iff the token is present with hooks ON and absent with hooks OFF.** That difference is the
   proof: a check that passes *both* ways would be testing nothing. The token is random per run, so
   no edit to the fixture can pre-satisfy it.

The probe agent runs a **minimal standalone persona** that never mentions `now.md`, the token, or
`HOOK_OK.txt` — so a passing token is attributable *only* to the hook.

## Isolation + safety

Single agent, no team (this tests launch/hook plumbing, not coordination). Each leg **self-isolates**:
its own scratch bus root (`$SB/st-root`) that `st launch` binds into the session env — your live
network is never touched. Sessions are collision-proof and torn down **zero-orphan** (agents + any
sidecars). If the agent commits, isolation attributes it (author-pinned to `hi-agent`).

## Grading

`fixture/grade.sh <SB_ON> <SB_OFF>` (run.sh calls it):
- **HARD — hooks ON:** `repo/HOOK_OK.txt` contains exactly `REHYDRATE-<token>` → SessionStart fired + rehydrated.
- **HARD — hooks OFF (control):** no such token → the ON assertion depends on the hook.
- **Soft:** isolation (only `hi-agent`/seed authored commits); boot-ritual observation (status flip, welcome-note drained) — corroborating, not gated.
- **Autonomy:** rescues = 0. A hook that needs a human poke to "fire" is a fail.

## Scope

**v1 (this cell): the SessionStart leg** — deterministic, fires on every launch, load-bearing for the
boot ritual + restart-continuity rehydrate. **v2 (planned):** StopFailure (status flip + ding on an
API error) and PreCompact (now.md flush on compaction) — both need a deterministic fault trigger
(likely a smalltalk-side mock); see `task.toml [v2]`.
