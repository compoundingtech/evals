# pty-live-recovery

Held-out, model-free black-box coverage for the selected live-daemon recovery
protocol in [PTY PR #128](https://github.com/compoundingtech/pty/pull/128) at
exact head `9ad3a4368027d8a9e78a22319615a3ab837347e1`.

Set `EVALS_PTY_PR128_ROOT` to a clean exact-head checkout after
`npm ci && npm run build`. The cell rejects any other Git head, package lock,
or built CLI/server artifacts. Its synthetic PTY roots and providers live only
inside the temporary eval catalog; it launches no model or provider harness.

## What it proves

- `pty recover <name> --snapshot <metadata.json>` is the only accepted surface.
- A private root advertises the complete protocol, secret, process-start,
  launch-identity, root/recovery-directory identity, and metadata-revision
  capability.
- Recovery preserves the daemon PID, generation, process-start token, launch
  identity, existing client, and provider while rotating the secret and signed
  metadata revision.
- A fresh client reaches the republished pathname, and every synthetic provider
  still has exactly one launch and one `session_start`.
- A rotated snapshot cannot replay; a pre-tag snapshot cannot roll back current
  metadata; and a secret-tampered snapshot cannot publish a registry. Each
  refusal leaves the original daemon alive and a current valid snapshot usable.
- Group/world-accessible root or `.recovery` modes fail before request/result,
  lock, socket, PID, or metadata publication.
- A daemon started without a recovery capability is refused without signal,
  restart, relaunch, or a recoverability claim.
- Cleanup binds every captured PID to its process-start token, uses bounded
  TERM then KILL only for those exact identities, fails if any survives, and
  exercises the KILL fallback with a TERM-resistant synthetic sentinel.

The experiment is exact-source draft evidence, not a merged release artifact.
It deliberately replaces the incompatible PR #127 oracle rather than merely
retargeting its metadata.

## Run it

```sh
EVALS_PTY_PR128_ROOT=/path/to/clean/pty-pr128 \
  st2 eval ./cells/pty-live-recovery/
```
