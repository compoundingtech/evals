# signal-rename — the cross-repo coordination crown-jewel (synthetic)

A tree of agents (a **supervisor + a specialist per repo**) carries out a coordinated **product rename** —
`signal` → `beacon` — that ripples from a base package out to two consumers + a config sweep, keeping every
suite green and the system working end-to-end.

The point isn't the rename; it's the **three skills** a real factory needs:
- **DECOMPOSITION** — who owns which repo.
- **SEQUENCING** — you can't rename the base package without breaking consumers until they're updated, so order
  + a **backward-compat/alias window** matter (a dual-honor cutover).
- **JUDGMENT** — `signal` also names a **primitive** (the OS signal + `AbortSignal`/`controller.signal`).
  Renaming *that* breaks everything. A blind `s/signal/beacon/g` fails this cell — the suites red and the
  quality judge catches the damage.

## The synthetic graph (materialized by `fixture/materialize.sh` as a run-step, never cloned)

| Repo | Role |
|---|---|
| **`@acme/signal`** (+ `signal` bin) | base package — the product to rename |
| **`signal-relay`** | consumer, judgment-heavy — peerDep `@acme/signal`; product refs **interleaved with** `AbortSignal`/`SIGTERM` primitive refs that must survive |
| **`signal-hub`** | consumer — drives `signal` sessions + a `signal://` scheme (→ `beacon://`) |
| **`app.toml`** | the product config sweep — the supervisor's own |

Everything is **invented** (`@acme/*`) → no real repos, no PII; it ships clean through both grep-gates.

## The two-way-failing suites (the ungameable pair)

- a test that **reds if the primitive is renamed** (exercises `AbortSignal`/`SIGTERM`) — catches over-eager replace;
- a **cross-repo integration test** that **reds if the product rename is incomplete** — catches under-done rename
  + bad sequencing.

**Held-out acceptance** (never shown): an isolated end-to-end run of the *renamed* stack — a `beacon` session
launches under the new bin, `signal-hub` connects over `beacon://`, an identity resolves, and the primitive is
still intact.

## Isolation (hard gate)

Each specialist owns **only** its own repo worktree; the base rename ripples to consumers **by message**
("renamed → bump your peerDep"), not by reaching across. A non-owner change to a repo = **instant FAIL**.

## Run it

```sh
st2 eval ./cells/signal-rename/
```

`signal-rename.kdl` is the canonical hand-authored agent declaration. A pre-boot `materialize` run-step builds
the bare origin, one full authored clone per agent (sup/base/relay/hub), and the held-out e2e location. It also
copies each source persona into its clone and writes `CLAUDE.md` loading `@PERSONA.md`. The four Claude seats use
event-first native bare `ding`: drain once, stand by for DING when idle, then drain, act, and archive after the
event. The runner owns the bus root and wake lowering.

Then `sig.sup` gets the rename kick and coordinates `sig.base` / `sig.relay` / `sig.hub` over the bus; each
pushes its lane to origin, and the sup integrates on main. Five KDL judges (`judges/`, grading `sig.sup`'s
integrated clone) cover isolation, suite-green, rename completeness, primitive integrity, and held-out e2e.
Caps: `claude,st,pty,git,node`.

Free preflight:

```sh
bin/check-corpus.sh
```

The scenario historically scored 6/6 in its original folder-eval conversion. The current native rewrite passes
both static gates but has not had a model-backed rerun; see the generated
[`../../CATALOG.md`](../../CATALOG.md).
