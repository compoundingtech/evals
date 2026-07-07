# ding-reply — the no-MCP reply path, exercised + asserted

A single agent launched **`st launch claude --ding` (no MCP)** receives a message and must **reply on the thread
over the `st` CLI** (`st message reply`). This is the **MCP-less config** — ding-only, no MCP, no macOS app — and
it's the exact coverage the **`st message reply` bug slipped through**: no other cell exercised *and asserted* the
CLI reply verb (they reply via the MCP tool, or only check that *a* message came back — which a fresh send fakes).

## The task + the discriminator

A synthetic requester (`dr-req`) seeds one message into `dr-agent`'s inbox: *"read `ANSWER.txt` and reply to THIS
message with its contents, on the thread."* The agent boots via ding (no MCP), reads it over the `st` CLI, reads
`ANSWER.txt`, and **replies via `st message reply`**. The grader's held-out check: the reply lands in `dr-req`'s
inbox with **`in-reply-to:` == the seeded kick** — which `st message reply` sets and a plain `st message send`
does **not** — plus the reply carries the `ANSWER.txt` token. **So it FAILS LOUD if the CLI reply verb is missing
or broken.** **Headline: autonomy — 0 rescues** (a first-class ding experience, not degraded).

## Run it

```sh
fixture/setup-sandbox.sh $SB     # agent cwd + ANSWER.txt
fixture/spin.sh $SB              # st launch --ding (no MCP) + seed the kick; agent replies over the st CLI
fixture/grade.sh $SB            # no-MCP + THREADED reply (in-reply-to) + the right answer
```

Self-isolating bus (`$SB/st-root`) — never the operator's live network. Caps: `claude,st,pty,git`. Complements
the MCP-opt-in path (proven by the MCP cells) — together the suite covers **both delivery paths, ding as the
default**.
