# ding-delivery-pty-ab

Matched, model-free PTY-boundary A/B for evals issue #57.

- **A** uses ordinary unguarded PTY input, matching the current aggressive
  unconfigured DING behavior.
- **B** is an external reference adapter: it attempts PTY input only when the
  exact live activity state is `idle`, its fixture-owned composer fact is
  empty, and `compareAndSend()` accepts the same generation and I/O revision.
  Otherwise the durable message remains queued for the deterministic post-turn
  hook.

Both arms receive identical durable bodies and preserve SHA256, exactly-once
delivery, FIFO, DND, hook retry, and restart recovery with zero model calls.
The active-turn case places the same partial human draft in both PTYs: A
physically appends its DING marker to that input stream, while B writes zero
DING bytes and the later hook delivers the message.

This cell runs against PTY activity base
`46c71d31c0d6daee43adf568061b2b84a65ae8c0` and stacked guarded-send successor
`743ceb796a41a3282e31382575bff0d0e3826d59`. Set
`EVALS_PTY_PR133_ROOT` to a clean exact-head checkout after
`npm ci && npm run build`.

The result proves the PTY-boundary strategy improves over aggressive input.
Configured generic-adapter selection, hook ownership, DND precedence, typed
receipts, and the same matrix through real generated task environments are now
covered separately by `ding-delivery-st2-rich-ab` against corrected st2 PR
#123. This cell remains the smaller PTY-boundary reference oracle.
