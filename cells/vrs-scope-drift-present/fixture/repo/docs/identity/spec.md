# identity implementation spec

The current implementation traces **R-ID-1** through `createAgent` and `parseIdentity`: constructed records
have `kind: "agent"`, and serialized input must use `agent:<id>`.

`createAgent` currently accepts a validated `id` and optional `displayName`, then freezes the returned record.
The optional agent-label behavior permitted by **R-ID-2** is not implemented yet.

Any non-agent identity kind remains outside this implementation under **R-ID-3**.
