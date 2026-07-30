# pty-attach-only

**Type:** pty / lifecycle policy · **Ship:** blocked on
[compoundingtech/pty#122](https://github.com/compoundingtech/pty/issues/122)

**Capabilities required:** `pty,jq,script`. No model and no bus. The cell uses
synthetic commands under an eval-owned PTY root.

**Discriminates:** can a relay request a strict attach-only policy that connects
to an existing daemon but never evaluates retained launch metadata? A dead
session must make `pty attach --no-restart <id>` exit nonzero without prompting
or creating another daemon incarnation.

## What it proves

- **Surface:** `pty attach --help` advertises `--no-restart`, preventing an
  unknown-option failure from masquerading as safe refusal.
- **Live positive control:** `--no-restart` attaches to a running reader, carries
  terminal input through an `ACK` round-trip, and exits with that process without
  creating another incarnation.
- **Mutation-valid control:** legacy `pty attach` receives queued future input
  through a real terminal and demonstrably restarts its synthetic dead target.
- **Noninteractive refusal:** a no-input terminal produces exactly one expected
  dead-session diagnostic and exits nonzero; the queued-input leg permits only
  that diagnostic plus terminal echo. No prompt, command presentation, or other
  interactive output is accepted.
- **No new incarnation:** the candidate target's marker and `session_start`
  event count both remain exactly one.
- **State preservation:** retained metadata remains `exited`, and neither its
  original pid nor any pid it still records identifies a live daemon for the
  synthetic root and session.
- **Isolation and cleanup:** both controls use `$CATALOG/attach-only-pty`, and
  the cell removes their exact synthetic records before grading.

## Run it

```sh
st2 eval ./cells/pty-attach-only/
```

This cell is intentionally RED until PTY implements the explicit attach-only
surface tracked in issue #122. The free corpus gate remains deterministic and
model-free.
