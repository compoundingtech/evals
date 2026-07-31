# pty-attach-outcomes-and-roles

**Type:** PTY installed-launcher and raw-socket composition. **Upstream
contracts:** the intentional machine-detach outcome and explicit same-socket
client-role replacement proposed against PTY main
[`d5fabc3917407aeb937a012bd97679c303e18033`](https://github.com/compoundingtech/pty/commit/d5fabc3917407aeb937a012bd97679c303e18033).

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
  min-grid; leaked demoted input; and a retained demoted size constraint.
- **Cleanup:** every socket is closed and every eval-owned daemon/session is
  removed.

The output barrier is causal rather than sleep-based: the anchor writes only
after the transitioning socket receives `STATUS`, and the PTY must emit the
anchor marker. Any earlier accepted input necessarily precedes that marker.

## Validation revisions

The acceptance cell was proven failing against PTY main `d5fabc3` and passing
against validation-only fork head
`d1365195a250fa94bb954092bfb521126d68b218`, which composes the runtime change
from detach candidate #146 (`698e8ebeff0ce5a97510a16612216d5d2ddbb483`;
current docs-complete head `badc3539c663bef74d53f2bf750b2cae48a71ed7`)
with role candidate
`138b6c6cf0e76d658ce3f2a893bf5eda2052bbfa`. The validation-only ref is not a
runtime dependency; after both corrections merge, the maintained cell runs
against the packaged PTY on merged main.

## Run it

```sh
st2 eval ./cells/pty-attach-outcomes-and-roles/
```
