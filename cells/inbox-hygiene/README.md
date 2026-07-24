# inbox-hygiene — exactly-once / archive-after-act across a cold restart

**Discriminates:** when the SAME work-item message is re-delivered and the agent is cold-restarted mid-flight,
does its archive-the-moment-it-acts hygiene + a durable ledger keep the work **exactly-once** — no double-act on
the re-drain? (durability, held-out)

**Capabilities required:** `claude,st,pty,git`.

## What it proves

The exactly-once / archive-after-act guarantee. `ih.agent` processes a work-item message (append its TOKEN to
`PROCESSED.log`, commit, and **archive the moment it acts** — not at the end). An eval-only injector re-delivers
the SAME message (un-archived) and cold-kills `ih.agent`; the `supervise` directive respawns it FROM SPEC (fresh
transcript, no `--resume`). On the re-drain the guard must recognize the already-handled token (from the durable
`PROCESSED.log`) and **NOT re-append** — a double-act is the failure. This is the archive-on-act hygiene from the
DING-BUS resume-safety contract, proven under a real restart.

## The team (`ih`)

`ih.agent` (owns the ledger repo) + `ih.inj` (the eval-only injector — re-delivers the message + cold-restarts the
agent; no bus voice).

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/inbox-hygiene/
```

Four held-out `judges/`: the resume double-act scenario was injected (re-delivered + cold-restart); **exactly-once**
(the TOKEN appears EXACTLY ONCE in `PROCESSED.log`); **archive-after-act** (inbox drained to empty, acted items in
archive); **isolation** (only `ih.agent` authored the ledger repo). Hermetic catalog.
