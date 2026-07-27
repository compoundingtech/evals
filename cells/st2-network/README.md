# st2-network — `st2 up` hosts a network end-to-end

The reboot host-proof: does **`st2 up`** actually **HOST** a network — bring a declared seat online (the supervisor
holds the host-lock, the seat's task stays alive) AND make the bus work (a message addressed to the hosted agent
is delivered to its inbox)? Ding-only, no MCP. (deterministic, held-out)

**Capabilities required:** `st2,pty,git`. The hosted seat is a deterministic sleep process; no model runs.
Contrast: **st2-network** here = does
the host command stand up a network; the newcomer zero-to-network onboarding path is parked separately (no st2
init/onboarding command yet).

## The scenario (team-less run-steps)

`st2-network.kdl` is a `run { }` eval over a hand-authored native net fixture:
- background `st2 up --catalog "$CATALOG/net" --host hetz` (the CLI host — it supervises the seat + holds the
  host-lock),
- deliver a message to the hosted agent over the real bus,
- assert the host is up and the message landed in the hosted agent's inbox, then explicitly tear it down.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/st2-network/
```

Held-out `judges/` (grading the run captures + the bus): **HOSTED** — `st2 up` supervises the seat and holds the
lock; **DELIVERED** — the message reaches the hosted agent's inbox. Hermetic catalog; never touches the live fleet.
