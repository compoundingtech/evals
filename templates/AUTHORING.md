# Authoring a cell — a worked example

This walks you through building one new cell from `templates/cell/`, end to end, mapping each step to
the file you edit and a **real cell** you can read for a working version. It also spells out the rules
that make a grader honest — the part that's easy to get wrong.

Read `../framework.md` first (the six axes, the isolation hard gate, the hermetic kick, the
visible/held-out split). This doc is the *how*; that one is the *why*.

---

## The worked example: `changelog-entry`

We'll author a tier-0 team cell: **a supervisor relays "add a changelog entry for the new `--json`
flag" to the worker that owns the repo; the worker writes it and commits; the supervisor verifies and
confirms.** It's deliberately shaped like `license-mit` — the smallest coordinated
delegate→execute→verify→confirm loop — but the task (and its held-out check) are its own.

**Why this cell earns its place** (the discriminator): it catches a supervisor that "helpfully" writes
the changelog *itself* — the entry would be correct, but the coordination guarantee is falsified.
Same failure-that-looks-like-success as `license-mit`, on a different task surface.

```sh
cp -R templates/cell cells/changelog-entry
```

Now fill in the TODOs, in this order.

---

## Step 1 — the synthetic world  (`fixture/setup-sandbox.sh`)

Materialize a **tiny, synthetic, deterministic** world, frozen at a base commit, with **no real
repos or identities**. For `changelog-entry`: a throwaway CLI repo whose `CHANGELOG.md` has an
`## [Unreleased]` section with **no** entry for the `--json` flag yet (so adding one is a *real*
change, not a no-op), plus a coordinate-only `sup/` dir.

Two things the template already does for you, and why they matter:

- **Pin the worker repo's git author to the owning agent** (`git config user.email
  "$WORKER_ID@eval.local"`). Without this the commit falls back to the operator's *global* git
  identity — the human running the eval — and the isolation gate ("only the owner committed") can't
  tell owner from operator. `license-mit` and `ghost-bug` both pin this way.
- **`.gitignore` the agent infra** (`CLAUDE.md`, `.mcp.json`, `pty.toml`, …) so harness files never
  land in the product repo and pollute attribution.

Reference: `cells/license-mit/fixture/setup-sandbox.sh` (a proprietary→MIT seed) and
`cells/inbox-hygiene/fixture/setup-sandbox.sh` (a solo ledger repo).

Smoke-check it in isolation the way CI does:

```sh
EVAL_SANDBOX=/tmp/ce cells/changelog-entry/fixture/setup-sandbox.sh /tmp/ce/changelog-entry
# must exit 0 and leave a non-empty sandbox — that's exactly what bin/smoke-setup.sh asserts
```

## Step 2 — the hermetic kick  (`fixture/kick.md`)

The team gets **exactly one** input. Write the outcome, not the procedure:

> "The changelog is missing an entry for the new `--json` flag. Please get it added."

Do **not** write "delegate to the worker, have them edit CHANGELOG.md under Unreleased, then verify."
The decomposition/delegation/verification must **emerge** from the personas — that's the system under
test. A kick that spells out the steps isn't testing anything. (Reference:
`cells/license-mit/fixture/kick-supervisor.md` — one sentence.)

## Step 3 — launch  (`fixture/spin.sh` + `configure-*-agent.sh`)

For a **team** cell, `spin.sh` (already scaffolded) does: `convoy init` an isolated network under
`$SB/st-root` → compose personas → `convoy add` each seat → seed the kick. Fill in `SUP_ID`/`WORKER_ID`
and the persona composition. Copy `compose-persona.sh` + `configure-claude-agent.sh` from `license-mit`
and adjust the seats.

> **convoy 0.2.x is declarative.** `convoy add` only *declares* a seat; the harness helper
> `stev_convoy_add` follows it with `convoy up --once "$NET"` to actually **spawn**. If you launch by
> hand, remember the `up --once` — an `add` alone starts nothing (this was defect #30).

For a **deterministic / probe** cell (no live team — e.g. the `convoy-doctor-*` cells), delete
`spin.sh` and ship a `probe.sh` that drives the tool and captures output for `grade.sh` to inspect.
Reference: `cells/convoy-doctor-structure/`.

## Step 4 — the held-out judge  (`fixture/grade.sh`)  ← the cell's spine

The grader reads **real state**, never a self-report. Four sources (mix as the cell needs):

| Source | How | Used for |
|---|---|---|
| message bus | `grep` inbox/archive frontmatter (`from:`, `in-reply-to:`) | coordination, threading, who-said-what |
| git | `git -C <repo> log --format='%ae'` | **isolation** (foreign author ⇒ FAIL); who did the work |
| convoy `--json` log | `grep '"type":"up"'` / `respawn` | convoy cells: hosted? respawned? |
| sandbox artifacts | a token/file the correct result must produce | task-success without trusting a claim |

For `changelog-entry` the checks are:

1. **Isolation (hard gate):** `git -C worker log --format='%ae'` contains *only* `$WORKER_ID@eval.local`.
   A commit by the supervisor here fails the run outright — even if the entry is perfect.
2. **Task success:** `CHANGELOG.md`'s Unreleased section now mentions `--json` **and** the tree is
   clean **and** it's committed. Accept *any* phrasing — grep for the flag under the right heading, not
   one exact line.
3. **Coordination (held-out):** the supervisor's confirmation landed in the requester's inbox with
   `in-reply-to:` == the seeded kick (a *threaded reply*, proving the loop closed on the bus, not a
   fresh send). Reference the exact idiom in `cells/ding-reply/fixture/grade.sh`.

End with the mechanical `SCORE` line, the autonomy headline, and `[ "$fail" -eq 0 ]` as the **exit-code
verdict** (0 = PASS). That exit code *is* the machine result today — there is no JSON verdict yet.

### The two rules that make a grader honest

- **Accept any correct solution.** Grep for the property, not a canonical diff. If only one exact patch
  passes, you're grading a fixture, not a system.
- **Validate it discriminates.** Run your grader against a **deliberately-wrong mock** and confirm it
  FAILS: e.g. commit the changelog entry *as the supervisor* (isolation must fail), or leave the flag
  out (task-success must fail). A grader that passes a wrong world is worthless. The strongest cells add
  a check a unit-test edit **can't fake** — replay the team's new test against the *original* commit and
  require it to fail there (`ghost-bug`), a mutation score (`test-writing`), or a cold-reader
  (`docs`).

## Step 5 — the spec + register it  (`task.toml`, `README.md`, `cells.manifest`, `REGISTRY.md`)

Fill `task.toml` (id must match the dir + manifest row; list only the axes this cell truly
discriminates) and `README.md` (lead with the one-sentence discriminator). Then register in **both**
catalogues, each at its **sorted (alphabetical)** position:

```
# cells.manifest
changelog-entry | team | ship | st,pty,convoy,git,claude | supervisor relays a changelog task; worker owns the edit; sup verifies — catches the sup doing the edit itself

# REGISTRY.md — the human row: discriminator + held-out acceptance + caps
```

Confirm it's wired:

```sh
bin/evals preflight | grep changelog-entry     # appears iff you have all its caps
```

---

## Run it end-to-end

```sh
bin/evals run changelog-entry                              # ensures pinned personas, then spin.sh
# observe the loop settle (until convoy eval lands its completion event, this is human-watched):
#   supervisor back to `available` + kick archived + a threaded confirmation in the requester's inbox
cells/changelog-entry/fixture/grade.sh "$EVAL_SANDBOX/changelog-entry"
bin/evals teardown "$EVAL_SANDBOX/changelog-entry"         # reap sessions + neuter pty.toml
```

## Pre-flight checklist before you call it done

- [ ] `bash -n` clean on every `fixture/*.sh`.
- [ ] `setup-sandbox.sh` exits 0 and leaves a non-empty sandbox (what `bin/smoke-setup.sh` checks).
- [ ] The kick specifies the **outcome**, not the steps.
- [ ] The worker repo's author is **pinned** to the owner; agent infra is `.gitignore`d.
- [ ] `grade.sh` reads real state, accepts any correct solution, and **fails a wrong mock** (you ran it).
- [ ] There is a **held-out** check a unit-test edit can't fake.
- [ ] Rows added to `cells.manifest` **and** `REGISTRY.md`, both at sorted position; `preflight` sees it.
- [ ] No principal machine-specifics (absolute paths, hostnames, usernames) baked into shipped files.
