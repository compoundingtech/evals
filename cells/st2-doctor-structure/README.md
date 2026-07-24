# st2-doctor-structure — `st2 doctor` proves a running catalog is healthy

**Discriminates:** does `st2 doctor` actually **prove** a catalog is healthy — passing on a well-formed, running
net and **failing on a broken one**? (deterministic, held-out)

**Capabilities required:** `st2,pty,git`. No LLM — this cell grades `st2 doctor`'s verdict, not agent behavior.

## What it proves

`st2 doctor` health-checks a **running** catalog: tools on PATH, the supervisor (`st2 up`) holds the host-lock,
each agent's task is alive, and presence is fresh. It is read-only and honest-by-construction (it only checks
directly-observable state — no auth/hooks probe). A green `st2 doctor` = a correctly-set-up, working network. This
cell guards that the gate is real, not always-pass.

## Two halves (team-less run-steps)

`st2-doctor-structure.kdl` is a `run { }` eval over a minimal service-seat fixture (`net/`):
- **HEALTHY:** background `st2 up "$CATALOG/net" --host hetz` (holds the lock + boots the seat), poll until doctor
  first passes, then the final `st2 doctor` — greppable **"all checks passed"** + exit 0; then kill the host.
- **MUTATION-VALID BROKEN:** with no live host, `st2 doctor` must **flag** the missing supervisor
  (**"✗ supervisor (st2 up) running"**) + exit non-zero — proving the gate fails-closed on a bad net.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/st2-doctor-structure/
```

Three held-out `judges/`: healthy → all-checks-passed + exit 0; broken → ✗ supervisor flagged; broken exits
non-zero. Proven live: 4/4. Hermetic catalog; never touches the live fleet.
