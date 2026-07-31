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
  min-grid; leaked demoted input; and a retained demoted size constraint.
- **Cleanup:** every socket is closed and every eval-owned daemon/session is
  removed.

The output barrier is causal rather than sleep-based: the anchor writes only
after the transitioning socket receives `STATUS`, and the PTY must emit the
anchor marker. Any earlier accepted input necessarily precedes that marker.

## Validation revisions

The acceptance cell was proven failing against PTY main `d5fabc3` and passing
against validation-only fork head
`4dd713e5cd71b8ba5cc6b07ffeae8b82e7a31e96`. That head merges detach candidate
#146 at `b58db0c2244e5ebdf41859b9c87d1f28b202ae5e` and role candidate #147 at
`2c865a56c25e94a7f2546bc1d1dc002db96f023f` onto upstream main
`1c625c75702e032ff5dc455976ad75005cd2c1c8`, which already contains the attach
stream fixture prerequisite from #145. The validation-only ref is not a runtime
dependency; after both corrections merge, the maintained cell runs against the
packaged PTY on merged main.

## Run it

```sh
st2 eval ./cells/pty-attach-outcomes-and-roles/
```
