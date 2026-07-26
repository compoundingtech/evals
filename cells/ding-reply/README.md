# ding-reply — the no-MCP reply path, exercised + asserted

A single ding-only agent (no MCP) receives a message and must **reply on the thread over the `st2` CLI**
(`st2 message reply`). This is the **MCP-less config** — ding-only, no MCP — and it's the exact coverage the
**`st2 message reply` bug slipped through**: no other cell exercised *and asserted* the CLI reply verb (they reply
via the MCP tool, or only check that *a* message came back — which a fresh send fakes).

## The task + the discriminator

A synthetic requester (`dr-req`) seeds one message into `dr.agent`'s inbox: *"read `ANSWER.txt` and reply to THIS
message with its contents, on the thread."* The agent boots through event-first native bare `ding`: it drains
once, stands by for DING when idle, then drains, acts, and archives after the event. It reads `ANSWER.txt` and
**replies via `st2 message reply`**. The held-out check: the reply lands `in-reply-to:` == the seeded kick —
which `st2 message reply` sets and a plain `st2 message send` does **not** — plus the reply carries the
`ANSWER.txt` token. **So it FAILS LOUD if the CLI reply verb is missing or broken.**

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/ding-reply/
```

`ding-reply.kdl` is the whole eval: it copies the fixture (`work/` = `ANSWER.txt` plus a checked-in
`CLAUDE.md` loading `@PERSONA.md`), boots the single `exec claude` agent through native bare `ding`, delivers the
kick from `dr-req`, and runs two held-out judges: **threaded-reply** (the reply is `in-reply-to:` the kick and
carries the ANSWER token) and **no-mcp** (the agent has no `.mcp.json`). The runner owns the bus root and wake
lowering; the cell authors neither. Caps: `claude,st,pty,git`.

Free preflight:

```sh
bin/check-claude-native.sh cells/ding-reply
bin/check-claude-reset.sh cells/ding-reply
```

The scenario historically scored 2/2 in its original folder-eval conversion. The current native rewrite passes
both static gates but has not had a model-backed rerun; see
[`../../CLAUDE-NATIVE-READINESS.md`](../../CLAUDE-NATIVE-READINESS.md).
