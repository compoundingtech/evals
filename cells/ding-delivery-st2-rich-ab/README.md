# ding-delivery-st2-rich-ab

Integrated, model-free DING A/B for evals issue #57 against corrected st2
PR #123.

- **A** is the generated unconfigured DING sidecar and preserves the existing
  aggressive PTY path.
- **B** is the generated configured sidecar. Its generic adapter argv is
  expanded only from the final st2-managed task environment, publishes the
  harness-neutral activity envelope, and reaches PTY only through the exact
  generation/revision guard. Non-idle work is claimed by the generic
  `ding-control hook-owned` ingress and stays off the PTY.

The cell runs the same nine scenarios and 11 durable messages as the frozen
PTY-boundary A/B: idle, active turn with a partial draft, long child, DND,
stale activity, hook failure, crash/restart, compaction/clear, and a three-item
FIFO burst. It verifies exact bodies and SHA256 values at the inbox before
archiving, exactly-once order in both arms, real sidecar restart, typed rich
receipts, and zero residual PTY or exec processes.

Set `EVALS_ST2_PR123_ROOT` to a clean exact checkout of
`d7500b0fcad8bb268da9da96c0226d9caddbe305` built with
`cargo build --release --locked`. The accepted local-source Linux release
binary SHA256 is
`705ad3ebd0bce497a4117c7c7993505c0579fc1f7df2421e0525a22208f6949f`.
Set `EVALS_PTY_PR133_ROOT` to the clean built stacked PTY head
`743ceb796a41a3282e31382575bff0d0e3826d59`.

This is integrated st2 configured-DING evidence with a synthetic generic
adapter and deterministic hook consumer. It is not real-provider acceptance:
immutable Codex and Claude activity/hook fixtures, owner review, live-pane
acceptance, merged dependencies, and release artifacts remain separate gates.
No model or provider process is launched.
