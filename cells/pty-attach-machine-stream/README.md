# pty-attach-machine-stream

**Type:** pty / installed attach composition · **Upstream contract:**
[compoundingtech/pty#140](https://github.com/compoundingtech/pty/pull/140) and
[compoundingtech/pty#141](https://github.com/compoundingtech/pty/pull/141), merged on PTY main at
[`d5fabc3917407aeb937a012bd97679c303e18033`](https://github.com/compoundingtech/pty/commit/d5fabc3917407aeb937a012bd97679c303e18033).

**Capabilities required:** `pty,jq,node`. No model and no bus. The cell uses the `pty` executable on `PATH`,
not a source-tree module or `dist/cli.js` entrypoint.

## What it proves

- **Packaged launcher:** fd 3 crosses the shipped `bin/pty` boundary and carries a parseable v1 stream.
- **Real initial snapshot:** an eval-owned target daemon emits `GEOMETRY` immediately followed by `SCREEN`;
  the screen includes colored terminal state produced before attach.
- **Real reconnect snapshot:** an installed `pty remote-serve` process exposes the target through a one-shot
  local transport proxy. A synthetic `fabric dial` selector drops the first route and withholds the second until
  the target has produced another
  line. The one continuous fd 3 stream must then contain another adjacent `GEOMETRY`, `SCREEN` pair whose
  screen includes that line.
- **Framing boundary:** terminal content and `EXIT` are decoded from fd 3, while stdout stays empty and stderr
  contains only reconnect status. This catches both descriptor loss and protocol/text contamination.
- **Cleanup:** the target and both route servers are removed from the eval-owned PTY root.

The fixture controls only transport selection and the deliberate connection drop; the installed CLI, PTY daemon, remote routing, attach client,
snapshot serialization, reconnect loop, and packaged launcher are all exercised as shipped. This is broader
than the upstream unit tests and specifically models the composition consumed by a terminal UI such as
Fractal.

## Run it

```sh
st2 eval ./cells/pty-attach-machine-stream/
```

The accepted composition proof uses the packaged PTY flake at the exact merged revision above.
