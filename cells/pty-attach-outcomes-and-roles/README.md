# pty-attach-outcomes-and-roles

**Type:** PTY installed-launcher and raw-socket composition. **Upstream
contracts:** the intentional machine-detach outcome and explicit same-socket
client-role replacement proposed against PTY main.

**Capabilities required:** `pty,node`. No model and no bus. The cell executes
the `pty` binary selected by `PATH`; it does not import PTY source modules or
invoke `dist/cli.js`.

## What it proves

- **Intentional outcome:** the shipped `bin/pty` launcher preserves fd 3. Once
  its initial baseline is observed, one real Ctrl-\\ input produces one
  terminal, empty `DETACH`, clean descriptor EOF, empty stdout/stderr, and
  process status zero.
- **Truncation control:** a public administrative `pty kill` of a separate
  eval-owned session after its initial baseline closes fd 3 without `EXIT` or
  `DETACH`; the attach process must exit nonzero. This distinguishes abrupt
  session loss from an intentional local user action.
- **Role promotion:** one raw socket sends `PEEK`, then `ATTACH`, terminal data,
  `RESIZE`, and `STATUS`. A separate attached anchor provides an output barrier.
  The promoted client becomes writable and changes the shared grid from
  `30x100` to `18x60`.
- **Role demotion:** another raw socket sends `ATTACH`, then `PEEK`, followed by
  forbidden `DATA` and `RESIZE` plus a `STATUS` barrier. Its constraint is
  removed, the grid returns to the anchor's `30x100`, and no forbidden bytes
  reach the PTY before a later anchor marker.
- **Oracle mutations:** synthetic observations reject a missing, non-empty, or
  wrong detach outcome; false truncation success; failed promotion; wrong
  min-grid; leaked demoted input; a retained demoted size constraint; and an
  empty session catalog with a live daemon or child PID.
- **Cleanup:** every socket is closed, cleanup commands succeed, the session
  catalog is empty, and every captured eval-owned daemon and child PID is dead.

The output barrier is causal rather than sleep-based: the anchor writes only
after the transitioning socket receives `STATUS`, and the PTY must emit the
anchor marker. Any earlier accepted input necessarily precedes that marker.

## Validation revisions

The acceptance cell was proven failing against PTY main `d5fabc3` and passing
against the packaged PTY built from merged upstream main
`9eb958c5aae026d5c05690ab72b528662c55708d`. That revision contains the attach
stream fixture prerequisite from #145, intentional detach outcomes from #146,
explicit same-socket role replacement from #147, and live-daemon registry
recovery from #128. The maintained cell now
runs directly against packaged PTY main; it has no validation-only runtime
dependency.

## Run it

```sh
st2 eval ./cells/pty-attach-outcomes-and-roles/
```
