# ghost-bug-codex — the ghost-bug debug loop, run by codex seats

Same eval as [`ghost-bug`](../ghost-bug/) (root-cause a shared-default-mutation bug in `labelkit` + a
**mutation-valid** regression test), but the team (`gbx.sup` + `gbx.fix`) runs on the **Codex** harness.
This teaches a bounded delegate-debug-verify loop where a shallow patch or a test that never failed
cannot pass.

**Run it:** `st2 eval ./cells/ghost-bug-codex/`

Held-out judges (identical logic to ghost-bug): isolation (author-gated to `gbx.fix`), suite-green,
root-cause (two blind probes), **regression mutation-valid** (RED on the buggy BASE src — the integrity
bar, ported verbatim), coordination.

Fixture `worker/` reuses ghost-bug's labelkit (owner-pinned `gbx.fix`); `worker/AGENTS.md` + `sup/AGENTS.md`
are intentionally pre-seeded complete Codex personas. The KDL uses native bare `ding`, with no authored
bus path or compatibility wake command.

Run provenance and current pass evidence live in [`../../HARNESS-MATRIX.md`](../../HARNESS-MATRIX.md).
