# convoy-network — the capstone: `convoy up` hosts a ding-only, no-MCP network end-to-end

The **reboot go/no-go proof.** It stands up, **HOSTS**, and exercises a complete agent network the way the
rebooted world will run it: `convoy up` as the foreground host (TCC anchor + supervisor + respawn owner),
**ding-only, no MCP, no macOS app**, with a real message→reply loop that closes — and a mid-run kill the host
must **respawn**. If this passes, the reboot's hosting model works.

## The scenario

`convoy add`s a **cos** (permanent) + **worker** (ding, no `.mcp.json`), hosts them with **`convoy up`** (which
reconciles + respawns gone permanent sessions, emitting a `--json` event stream), and seeds a delegate→do→reply
task. Mid-run, the **kill-injector** crashes the **permanent cos**'s process (kill its PID → it exits) — **`convoy
up` must respawn it** (resuming its session) and the loop must still close. *(LIVE-validated: convoy up respawns
PERMANENT sessions, not workers; and respawn fires on a crashed/exited session — a plain `pty kill` REMOVES the
record so the reconcile can't see it to respawn.)*

## The gates (parsed from `convoy up`'s `--json` log + the bus)

- **HOSTED** — `convoy up`'s `up` event (the CLI host supervises the agents).
- **NO-MCP** — no `.mcp.json` in any agent dir (`convoy add` is ding-by-default).
- **NO-APP** — hosted by `convoy up` (CLI); no `Convoy.app` invocation.
- **RESPAWN** *(the new gate)* — a `{type:respawn, identity:cap-cos, ok:true}` event **after** the crash: the HOST
  (not the fixture) brought the permanent cos back, resuming its session (ties to resumability).
- **LOOP-CLOSED** — a **threaded** reply from cos in the requester's inbox (`in-reply-to` == the kick — reuses
  ding-reply's discriminator) carrying the `ANSWER.txt` token.
- **autonomy — 0 rescues.**

## Run it

```sh
export CONVOY_BIN=/path/to/convoy      # a convoy WITH `up` (installed 0.1.0 lacks it — see below)
fixture/setup-sandbox.sh $SB           # convoy init the isolated network + agent dirs
fixture/spin.sh $SB                   # convoy add cos + worker (ding) + convoy up (host, --json log)
fixture/kill-injector.sh $SB          # crash the PERMANENT cos mid-run → convoy up must respawn
fixture/grade.sh $SB                 # HOSTED + respawn + no-mcp + no-app + threaded reply
```

**Dependency:** the installed `convoy` (0.1.0, `/opt/homebrew/bin`) does **not** have `up` yet — set `CONVOY_BIN`
to a built/re-published binary until it ships. Composes bootstrap + ding + resumability into one end-to-end host
proof; binds to convoy's frozen `convoy up` interface. Design: `CONVOY-UP-CAPSTONE-DESIGN.md`. Caps:
`claude,convoy,st,pty,git`.
