# crash-ding — a crashed worker dings its supervisor chain

**Discriminates:** when a supervised worker **crashes** (its pty session dies non-cleanly — killed / vanished /
non-zero exit), does st2 respawn it AND send a `worker crash: <id>` bus message up its **whole supervisor chain**
(the direct supervisor AND the root CoS), so a supervisor learns its worker died without polling — while a **clean
exit stays silent**? (deterministic, held-out)

**Capabilities required:** `claude,codex,st,pty,git`.

## What it proves

The events/notifications path. It is **harness-agnostic by construction**: it keys on the pty SESSION dying, so
the same edge fires for a real **codex** worker (`cd.xw`) and a real **claude** worker (`cd.cw`). A false ding on a
routine finish is as bad as a missed crash, so a clean exit (code 0) must send NOTHING.

## The team (`cd`)

`cd.cos` (root, no supervisor) → `cd.sup` (supervisor `cd.cos`) → workers: `cd.cw` (claude), `cd.xw` (codex),
`cd.oom` (crashes with exit 137), `cd.clean` (exits 0), plus `cd.inj` (an eval-only crash-injector that
`kill -9`s the workers once alive — SIGKILL, since codex catches SIGTERM and exits clean). The `supervise`
directive respawns dead seats from spec and emits the crash-dings up each chain.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/crash-ding/
```

Five held-out `judges/`: claude-worker crash reaches the **supervisor**; it reaches the **CoS** too (up the chain);
**harness-agnostic** (the codex worker crash also dings sup + cos); a **non-zero-exit (137)** crash dings (not just
a kill); and a **clean exit (0) is SILENT** (no ding anywhere). Hermetic catalog.
