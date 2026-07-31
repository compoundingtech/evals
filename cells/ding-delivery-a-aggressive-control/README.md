# ding-delivery-a-aggressive-control

Current-product, model-free control for unconfigured DING on st2
`c6846f6239329f0803142afc06c15a07b93937c1` with PTY activity base
`46c71d31c0d6daee43adf568061b2b84a65ae8c0` and stacked guarded-send head
`743ceb796a41a3282e31382575bff0d0e3826d59`.

The target has no activity publisher, so live activity is exactly `unknown`.
With no rich adapter configuration, st2 still invokes ordinary `pty send`; the
synthetic raw composer records those bytes. Because the synthetic pane does not
emit a provider-specific positive receipt, st2 correctly retains staged
ownership and leaves the durable inbox message unread.

This isolates the aggressive baseline fact needed by issue #57 without
pretending the older multi-message `presence-ding-matrix` is compatible with
the positive-receipt semantics added by st2 `c6846f6`.
