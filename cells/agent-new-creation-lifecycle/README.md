# agent-new-creation-lifecycle

This is the model-free lifecycle admission cell for the real zero-flag
`axe agent new` transaction. It is intentionally unrun and non-accepting until
the successor Axe artifact and its model-free driver are pinned. The driver
must invoke that exact Axe binary against a real canonical temporary Agent Spec
and st2 catalog; a shell stand-in is not admissible.

Required run inputs:

- `AXE_AGENT_NEW_SUCCESSOR`: exact immutable Axe executable;
- `AXE_AGENT_NEW_SUCCESSOR_COMMIT`: its 40-hex source commit;
- `AXE_AGENT_NEW_LIFECYCLE_DRIVER`: immutable model-free driver which invokes
  that executable and writes the documented case state.

The cell covers success, three crash boundaries, cancellation versus process
failure, single-flight recovery, retained tombstones, main-PTY gating with Ding
state explicitly indeterminate, exactly-once final publication, and attachment
to the exact final PTY. It distinguishes raw terminal Ctrl-C (`0x03`), which is
forwarded and does not cancel, from the primary human cancellation path: a
clean `pty attach` detach via Ctrl+\. External SIGINT/exit 130 is a separate
secondary cancellation path. Until an exact successor supplies those inputs,
`st2 eval` must fail before claiming a result.
