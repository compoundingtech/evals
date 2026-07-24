# ghost-bug-codex — the ghost-bug debug loop, run by codex seats

Same eval as [`ghost-bug`](../ghost-bug/) (root-cause a shared-default-mutation bug in `labelkit` + a
**mutation-valid** regression test), but the team (`gbx.sup` + `gbx.fix`) runs on the **codex** harness —
proving the folder-eval format handles codex seats. Codex reads its persona from `AGENTS.md` (not
`CLAUDE.md`), and each seat gets a `st2 ding` wake sidecar (codex has no async re-wake).

**Run it:** `st2 eval ./cells/ghost-bug-codex/`

Held-out judges (identical logic to ghost-bug): isolation (author-gated to `gbx.fix`), suite-green,
root-cause (two blind probes), **regression mutation-valid** (RED on the buggy BASE src — the integrity
bar, ported verbatim), coordination.

Fixture `worker/` reuses ghost-bug's labelkit (owner-pinned `gbx.fix`); `worker/AGENTS.md` + `sup/AGENTS.md`
are the codex personas.
