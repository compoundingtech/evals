# pty-send-peek

**Type:** pty / verb-surface · **Ship:** ship

**Capabilities required:** `pty,git`. No LLM, no bus — pure
pty. Deterministic: a cell-specific sentinel + a fixed ACK-reader process, so the outcome is fully determined.

**Discriminates:** does the **pty verb surface actually work** — does `pty send` deliver bytes the session's
process receives and acts on, and does `pty peek` return the session's real live output? The suite spawns and
restarts sessions everywhere as plumbing, and `two-networks-coexist` asserts that *cross-network* peek/send is
**refused** — but nothing grades peek/send as a **working capability**. This is that positive round-trip.

## What it proves

The session runs a deterministic **ACK-reader** (`printf READY`, then `ACK:<line>` per input line):

- **Round-trip:** `pty send <id> --seq "<tok>" --seq key:return` injects a **random per-run** token; then
  `pty peek --plain` shows `ACK:<tok>`. The `ACK:` prefix is emitted by the **process**, so a matching ACK
  proves the process *received and acted on* the sent bytes (not just terminal echo), and that peek returned
  the real output.
- **Negative control (mutation-valid):** a peek taken **before** the send does **not** contain `ACK:<tok>` —
  so peek reflects real state and the ACK appears only because `pty send` delivered the input. The token is
  specific to this cell, and the pre-send assertion prevents a fixture from pre-baking the acknowledged form.
- **Isolation:** the session lives in the eval's scratch `PTY_ROOT`; the grader runs the same `pty list`
  query twice while it is alive—once against the eval registry and once with `PTY_ROOT` unset—and requires
  the session to be listed only in the eval registry. Both halves gate, so a wrong or unreadable registry
  cannot pass as an empty result.
- **Self-cleanup:** after capturing the ACK, the cell kills its ad-hoc reader and a held-out judge proves no
  running `psp` session remains even when the eval catalog is preserved with `--keep`.

## Run it

```sh
st2 eval ./cells/pty-send-peek/
```

`pty-send-peek.kdl` is a team-less run-step eval: its run steps spawn the ACK-reader pty, send the token,
capture the screen and both registry views, and kill the reader; five held-out judges assert the round-trip,
negative control, live-output evidence, dual-registry isolation, and zero-running-session cleanup. Net-free
and self-cleaning even when the hermetic catalog is preserved for inspection.
