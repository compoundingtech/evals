# two-networks-coexist — multi-tenant isolation (bus + pty)

Two independent smalltalk networks run **concurrently on one host** and must stay **hermetically partitioned** —
neither can enumerate, address, deliver to, or (via pty) see/inject into the other. This raises the isolation
hard-gate from *"an agent stays in its repo lane"* to **tenant partition across two networks**: the multi-tenancy
promise the system makes the moment a second network exists on a machine, and which has never been asserted.

It is **persona-independent** — it grades the **substrate** (bus + pty), not agent judgment.

## The two surfaces that can leak

1. **Bus (`ST_ROOT`)** — messages are files under `$ST_ROOT/<id>/inbox`. Two networks = two disjoint roots. A
   leak = message bleed or cross-enumeration.
2. **pty (`PTY_ROOT` / `st.network` tag)** — both networks' agents are pty sessions. A shared pty daemon would let
   network A `pty ls`/`peek`/`send` network B's sessions, **bypassing the bus entirely** (read another tenant's
   screen, inject keys). Per-network `PTY_ROOT` (merged) partitions them physically; this cell is its acceptance test.

## The sharpest probe — same-identity collision

Both networks contain an agent named `cos`/`wk`. If the bus keyed on identity alone, a message for `wk` would be
ambiguous and could leak; correct isolation keys on **root + identity**, so each `wk` sees only its own network. The
collision means a pass can't be an accident of unique names.

## The held-out probe battery (both directions, after both nets are live)

| Probe | PASS |
|---|---|
| **P-enumerate** | `st agents` in A lists only A's agents |
| **P-deliver-collision** | A→`wk` lands in A's `wk`; B's `wk` inbox unchanged |
| **P-cross-address** | A→B-only `beacon-b` never reaches `$ST_ROOT_B/beacon-b/inbox` |
| **P-pty-visibility** | B's pty sessions invisible/unaddressable from A (per-network `PTY_ROOT`) |
| **P-fs-scope** | each root holds only its own network's dirs |

**Liveness (positive control):** each network independently completes its own seeded one-line task concurrently —
proving the partition isn't the trivial "two dead networks" pass. **Isolation is the whole grade.**

## Two builds (infra first)

1. **Pure-infra probe battery** *(build first — the deterministic hard gate)*: the harness plays the agents via
   shell `st`/`pty` calls (+ cheap `sleep` pty sessions for the pty probe). **No `claude` bootstraps → runs on
   any box**, no machine-load dependency. This is the CI-able, ungameable gate.
2. **Live-agents concurrency run** *(the demo beat)*: real agents in both networks under real load — same battery.
   Env-heavy → runs on the quiet/bare box (like signal-rename's live grade).

## Run it

```sh
bin/st-evals run two-networks-coexist   # (once wired) two-roots spinner → probe battery → grade
```

Caps: `st,pty,git,node` (+`claude` only for the live build). Spec: `task.toml`. Design:
`TWO-NETWORKS-COEXIST-DESIGN.md` (private evals repo).
