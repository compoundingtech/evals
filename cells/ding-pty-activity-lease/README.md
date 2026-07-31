# ding-pty-activity-lease

Model-free black-box coverage for the generic PTY activity lease introduced by
draft PTY PR #131 at exact head
`46c71d31c0d6daee43adf568061b2b84a65ae8c0`. The runnable experiment uses the
stacked PR #133 successor source at exact head
`743ceb796a41a3282e31382575bff0d0e3826d59`, which contains that exact base
and the owner-reviewed combined fixtures.

Set `EVALS_PTY_PR133_ROOT` to a clean checkout at the stacked head after
`npm ci && npm run build`. The cell verifies both Git identities before using
the public `connectActivityPublisher()` and `queryStats()` APIs. This is
exact-source experiment evidence, not a release artifact.

The cell proves ordered activity transitions, single-publisher ownership,
fail-closed sequence handling, diagnostic-only alternate-screen state,
generation reset, and zero remaining PTY sessions. It launches no provider or
model.
