# pty-send-peek

**Type:** pty / verb-surface · **Ship:** ship

**Capabilities required:** `pty,git`. No LLM, no bus — pure
pty. Deterministic: a random per-run token + a fixed ACK-reader process, so the outcome is fully determined.

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
  random per run, so no fixture can pre-bake the screen.
- **Isolation:** the session lives in a scratch `PTY_ROOT` (`pty --root`); the grader asserts it is **invisible**
  in the operator's global pty registry.

## Run it

```sh
st2 eval ./cells/pty-send-peek/
```

`pty-send-peek.kdl` is a team-less run-step eval: its `run { step … }` spawns the ACK-reader pty, sends a random
token, and captures the screen before + after; the held-out `judges/` assert the round-trip + a negative control +
isolation from the captured screen. Net-free and self-cleaning (the hermetic catalog is torn down at the end).
