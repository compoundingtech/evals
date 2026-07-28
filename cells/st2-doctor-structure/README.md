# st2-doctor-structure — `st2 doctor` proves a running catalog is healthy

**Discriminates:** does `st2 doctor` actually **prove** a catalog is healthy — passing on a well-formed, running
net and **failing on a broken one**? (deterministic, held-out)

**Capabilities required:** `st2,pty,git`. No LLM — this cell grades `st2 doctor`'s verdict, not agent behavior.

## What it proves

`st2 doctor` health-checks a **running** catalog: tools on PATH, supervision mode, each agent's task is alive,
and presence is fresh. A live `st2 up` host lock is healthy; no host lock is also a valid explicit
manual/`--once` mode, while a stale lock is unhealthy. It is read-only and honest-by-construction (it only
checks directly-observable state — no auth/hooks probe). A green `st2 doctor` = a correctly-set-up, working
network. This cell guards that the gate is real, not always-pass.

## Two halves (team-less run-steps)

`st2-doctor-structure.kdl` is a `run { }` eval over a minimal hand-authored native service-seat fixture (`net/`):
- **HEALTHY:** background `st2 up --catalog "$CATALOG/net" --host hetz` (holds the lock + boots the seat), poll
  until doctor first passes, then the final `st2 doctor` — greppable **"all checks passed"** + exit 0; then
  explicitly tear the catalog down.
- **MUTATION-VALID BROKEN:** after teardown, the active declarations retain task records whose sessions are
  gone. `st2 doctor` must report valid manual/`--once` supervision, **flag both the `agent` and `ding` tasks
  as `session dead/missing`**, and exit non-zero — proving the gate fails-closed on the planted outage.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/st2-doctor-structure/
```

Four held-out judges: healthy → all-checks-passed + both declared tasks alive with no dead/missing
diagnostic; broken → valid manual supervision + both declared tasks dead/missing; broken exits non-zero.
Hermetic catalog; never touches the live fleet.
