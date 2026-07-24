# hook-integrity — does your Claude Code SessionStart hook actually FIRE?

**Discriminates:** a Claude agent's **SessionStart hook FIRING** (proven from ground truth) vs merely
being *configured*. Reading `settings.local.json` proves configuration — which was already true in the
field case this comes from, where hooks were configured but silently never ran. This proves execution.

**Capabilities required:** `claude,st,pty,git`

> **⚠ Status: KNOWN RED (documented, not a regression) — HOOKS-OFF CONTROL fails on claude 2.1.x.**
> The negative control assumes the SessionStart hook is the *only* path to `now.md`. It isn't: a modern
> claude agent, told to "act on your durable working state," runs `st context read` (or Reads the file)
> and gets the same `now.md` — token and all — **without** the hook. Ground truth (a `--keep` run): the
> OFF-leg hook did **not** fire (zero `<context source=…>` injections), yet the agent still wrote the
> token via that non-hook read. It passed before only because older claude didn't self-fetch its durable
> state — **green by luck, now exposed.** The **discriminator redesign is pending Nathan's pick** (leaning:
> gate the token on the hook's `<context source=…>` envelope, which `st context read` does not add;
> fallback: key on a hook direct-execution trace). The boot-fix + flat-run conversion below are correct
> regardless and are applied; only the redesign is held.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/hook-integrity/     # render the REAL hook into 2 legs → seed now.md → boot ON + hooks-disabled OFF → judge
```

The whole eval is `hook-integrity.kdl`. `fixture/setup.sh` runs as the eval's `run "setup"` (before boot):
it `st2 render-agent`s the **real** SessionStart hook (smalltalk `session-start.sh`) into two identical workspaces
(`repo-on`, `repo-off`) and seeds the **same** per-run secret token into each leg's `context/now.md`. Two team
agents boot identically **except** `hi.off` adds `--settings disableAllHooks` (claude 2.1.x dropped the old
`--no-hooks`). See the KNOWN RED note above for the current control status.

## What it proves — the ungameable core

The SessionStart hook injects your agent's durable working-state (`context/now.md`) as a `<context>`
block on its first turn — **only if it fires**. The diagnostic exploits that:

1. It seeds `now.md` with a **secret token** generated fresh this run — reachable **no other way**:
   not in the agent's persona, not in its repo, not in its inbox. `now.md` tells the agent to write
   `REHYDRATE-<token>` into `HOOK_OK.txt`.
2. It boots the agent in **two legs**, identical except one flag (the real SessionStart hook, written by
   `st2 render-agent`, is configured in BOTH):
   - **hooks ON** (`hi.on`, plain `exec claude`) → if the hook fires, the agent sees the token and writes it. ✅
   - **hooks OFF** (`hi.off`, `exec claude --settings '{"disableAllHooks":true}'`) → the negative control.
     Same hook configured, but claude does not fire it → no injection. ❌ *(KNOWN RED on claude 2.1.x — the
     agent reaches `now.md` via `st context read` regardless; see the Status note above.)*
3. **PASS iff the token is present with hooks ON and absent with hooks OFF.** That difference is the
   proof: a check that passes *both* ways would be testing nothing. The token is random per run, so
   no edit to the fixture can pre-satisfy it.

The probe agent runs a **minimal standalone persona** that never mentions `now.md`, the token, or
`HOOK_OK.txt` — so a passing token is attributable *only* to the hook.

## Isolation + safety

A two-agent team `hi` (`hi.on` + `hi.off`), no coordination (this tests hook plumbing). Each leg is a hermetic
catalog workspace — your live network is never touched. Sessions are torn down **zero-orphan** (agents + any
sidecars). If the agent commits, isolation attributes it (author-pinned to `hi-agent`).

## Grading (held-out judges in `judges/`)

- **HOOKS-ON FIRED (hard):** `repo-on/HOOK_OK.txt` contains exactly `REHYDRATE-<token>` → SessionStart fired + injected `now.md`.
- **HOOKS-OFF CONTROL (hard):** `repo-off/HOOK_OK.txt` is absent/tokenless → the ON assertion depends on the hook (a check that passed both ways would test nothing). **⚠ Currently RED on claude 2.1.x** — see the Status note at the top; discriminator redesign pending Nathan.
- **HOOK-EXCLUSIVE (attribution):** the token appears in **no agent seed input** — persona, kick, repo-seed, inbox — only in `context/now.md` (the hook channel). The agent's *outputs* (its `HOOK_OK.txt`, its bus report to the requester, its transcript) legitimately carry it and are excluded.

## Scope

**v1 (this cell): the SessionStart leg** — deterministic, fires on every launch, load-bearing for the
boot ritual + restart-continuity rehydrate. **v2 (planned):** StopFailure (status flip + ding on an
API error) and PreCompact (now.md flush on compaction) — both need a deterministic fault trigger
(likely a smalltalk-side mock); see the design notes.
