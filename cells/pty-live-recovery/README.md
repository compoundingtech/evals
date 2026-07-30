# pty-live-recovery

**Type:** pty / lifecycle safety · **Ship:** blocked on
[compoundingtech/pty#126](https://github.com/compoundingtech/pty/issues/126)

**Capabilities required:** `pty,jq,bash`. No model and no bus. Every process and
registry path is synthetic and scoped to the eval-owned `$CATALOG`.

**Discriminates:** can the original live daemon republish an accidentally
unlinked pathname socket and registry without restarting its provider, changing
its identity, or disconnecting a client that was already attached?

## What it proves

- **Surface:** `pty recover-live --help` advertises a required metadata snapshot.
- **Positive control:** a live synthetic daemon survives explicit removal of
  only its socket, pid, and metadata paths.
- **Stable identity:** recovery preserves its exact daemon PID, generation, and
  OS process-start token.
- **Existing-client continuity:** a read-only client connected before unlink
  remains alive and receives an acknowledgement emitted after rebind.
- **New-client attachability:** a fresh peek reaches the replacement pathname.
- **No duplicate launch:** the provider marker and `session_start` count remain
  exactly one.
- **Fail-closed negative:** a snapshot without the recovery protocol marker and
  process-start token is refused without poking its synthetic daemon, which
  remains alive.
- **Isolation:** cleanup signals only PIDs captured from the eval root and then
  removes that exact root.

## Run it

```sh
st2 eval ./cells/pty-live-recovery/
```

The cell is intentionally RED until pty implements issue #126.
