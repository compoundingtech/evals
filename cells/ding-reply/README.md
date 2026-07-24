# ding-reply — the no-MCP reply path, exercised + asserted

A single ding-only agent (no MCP) receives a message and must **reply on the thread over the `st2` CLI**
(`st2 message reply`). This is the **MCP-less config** — ding-only, no MCP — and it's the exact coverage the
**`st2 message reply` bug slipped through**: no other cell exercised *and asserted* the CLI reply verb (they reply
via the MCP tool, or only check that *a* message came back — which a fresh send fakes).

## The task + the discriminator

A synthetic requester (`dr-req`) seeds one message into `dr.agent`'s inbox: *"read `ANSWER.txt` and reply to THIS
message with its contents, on the thread."* The agent boots via ding (an `st2 ding` sidecar for inbound + the
`st2` CLI for all bus ops — no MCP), reads it, reads `ANSWER.txt`, and **replies via `st2 message reply`**. The
held-out check: the reply lands `in-reply-to:` == the seeded kick — which `st2 message reply` sets and a plain
`st2 message send` does **not** — plus the reply carries the `ANSWER.txt` token. **So it FAILS LOUD if the CLI
reply verb is missing or broken.**

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/ding-reply/
```

`ding-reply.kdl` is the whole eval: it copies the fixture (`work/` = `ANSWER.txt` + the persona), boots the single
ding-only agent `dr.agent` (`exec claude` + an `st2 ding` sidecar, no `.mcp.json`), delivers the kick from
`dr-req`, and runs two held-out judges: **threaded-reply** (the reply is `in-reply-to:` the kick + carries the
ANSWER token) and **no-mcp** (the agent has no `.mcp.json`). Caps: `claude,st,pty,git`. Complements the MCP-opt-in
path — together the suite covers **both delivery paths, ding as the default**.
