# ding-pty-guarded-send

Model-free black-box coverage for revision-guarded PTY input introduced by
draft PTY PR #133 at exact head
`743ceb796a41a3282e31382575bff0d0e3826d59`, stacked on activity PR #131 at
`46c71d31c0d6daee43adf568061b2b84a65ae8c0`.

Set `EVALS_PTY_PR133_ROOT` to a clean checkout at the stacked head after
`npm ci && npm run build`. The cell verifies the exact Git identities and uses
only public package APIs.

It proves one exact guarded write, replay rejection, zero candidate bytes after
ordinary input, output, resize, activity, or generation races, viewer-without-I/O
eligibility, malformed/empty/oversize rejection, and complete cleanup. PTY does
not prove provider idle or an empty composer; those remain adapter authority.
