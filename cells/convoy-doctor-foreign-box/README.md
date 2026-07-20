# convoy-doctor-foreign-box

**Type:** structure / diagnostic-honesty · **Ship:** ship

**Capabilities required:** `convoy,st,pty,git` · run `bin/evals preflight` to confirm. No LLM — the claude auth
probe is driven by a shim, so the outcome is deterministic (no live auth needed). Box-free (`--quick` spawns no agents).

**Discriminates:** does `convoy doctor` tell the TRUTH on a **foreign box** — a machine that isn't the one that
set the network up, so `st` is off `PATH` and a claude auth probe errors for a non-auth reason — or does it
FALSE-fail a healthy setup ("your hooks are missing", "you're signed out")? The regression guard for the two
Johannes false-negatives fixed in convoy **#77** (auth-probe classifier) + **#78** (st-hooks discovery).

## What it proves (Nathan's bar — the doctor must not say untrue things)

On a foreign box (`st` genuinely removed from the run's `PATH`, hooks wired via each agent's absolute `ST_BIN`):

- **HOOKS honesty (#78):** with `st` off `PATH` (doctor's Tooling leg flags `✗ st NOT on PATH`), the Hooks leg
  must NOT say a false `smalltalk hooks NOT found`. Discovery goes through `ST_BIN` before `which st`, so it
  honestly reports `✓ smalltalk hooks found` — or, if it truly can't locate them, a non-blocking WARN that never
  asserts absence. (Pre-#78 keyed off `which st` and hard-failed "NOT found" on an st-off-PATH box.)
- **AUTH honesty (#77):** an **inconclusive** probe — a `claude` shim that errors for a non-auth reason (a
  sandbox denial) — is reported as `✗ could not verify Claude auth — the probe errored`, NOT a false
  `✗ Claude is NOT signed in`. (Pre-#77 an over-broad `AUTH_FAIL` mislabeled any errored probe as signed-out.)
- **Mutation-valid contrast:** the SAME foreign box with a `claude` shim that prints a CLEAR
  `Not logged in · Please run /login` DOES produce `✗ Claude is NOT signed in`. So the auth check is
  non-vacuous — it *can* and *does* report signed-out on a real signal, which makes the honest pass meaningful.

## Run it

```sh
fixture/probe.sh <SB>   # builds the foreign box (st off PATH + claude shims) + runs `convoy doctor --quick` twice
fixture/grade.sh <SB>   # asserts hooks + auth honesty + the mutation-valid contrast (grades doctor's REAL output)
```

or `bin/evals run convoy-doctor-foreign-box`. Use a SHORT `<SB>` (e.g. `/tmp/cdfb`) so `PTY_ROOT` stays under the
doctor's path-length gate. Greenfield-safe: scoped with `--network` + a clean env, `--quick` spawns no agents,
never touches the live fleet. If the local convoy predates #77/#78, the cell goes RED until the box is synced to
a tree that includes both fixes.

> **Dev-box note.** On a machine where convoy sits beside a `smalltalk` checkout, discovery's `../smalltalk`
> sibling also locates the hooks, so the (#78) leg here is a *no-false-absence* guard; a true Johannes box with
> no sibling exercises the `ST_BIN` discovery path fully. The (#77) auth leg is fully reproduced either way.
