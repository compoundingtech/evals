# convoy-network — `st2 up` hosts a network end-to-end

The reboot host-proof: does **`st2 up`** actually **HOST** a network — bring a rendered seat online (the supervisor
holds the host-lock, the seat's task stays alive) AND make the bus work (a message addressed to the hosted agent
is delivered to its inbox)? Ding-only, no MCP. (deterministic, held-out)

**Capabilities required:** `st2,pty,git` (+ `claude` for the hosted seat). Contrast: **convoy-network** here = does
the host command stand up a network; the newcomer zero-to-network onboarding path is parked separately (no st2
init/onboarding command yet).

## The scenario (team-less run-steps)

`convoy-network.kdl` is a `run { }` eval over a rendered net fixture:
- background `st2 up "$CATALOG/net" --host hetz` (the CLI host — it supervises the seat + holds the host-lock),
- deliver a message to the hosted agent over the real bus,
- assert the host is up and the message landed in the hosted agent's inbox.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/convoy-network/
```

Held-out `judges/` (grading the run captures + the bus): **HOSTED** — `st2 up` supervises the seat and holds the
lock; **DELIVERED** — the message reaches the hosted agent's inbox. Hermetic catalog; never touches the live fleet.
Design: `CONVOY-UP-CAPSTONE-DESIGN.md`.
