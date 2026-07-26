# license-mit-codex — the smallest team loop, run Codex-native

Cross-family variant of [`license-mit`](../license-mit/): the **same** task, world, and grader; the only
variable is the family. Where `license-mit` runs a Claude/Mixed team, this runs a **full-Codex** team
(`lmc.sup` + `lmc.worker`), confirming the delegate → execute → verify → confirm loop closes Codex-native,
not only on Claude.

- **Task** (`task.md`): one instruction — "the license should be MIT" — into `lmc.sup`'s inbox.
- **Team/persona mechanism**: the copied fixture intentionally pre-seeds a complete `AGENTS.md` in
  `sup/` and `worker/`; Codex loads those files directly. The KDL uses native bare `ding`, so it contains
  no authored bus path or compatibility wake command. `lmc.sup` coordinates + owns no repo;
  `lmc.worker` owns the `widget` repo and makes/commits the change; `lmc.sup` verifies read-only and
  confirms. Every eval starts from the frozen `worker/_git` snapshot, rehydrated as `.git` only inside
  the throwaway catalog.
- **Judges** (all held-out): structural isolation (sup owns no repo), the coordination loop on the bus
  (delegate → report → verified-confirm post-dating the report), `LICENSE` is canonical MIT, `package.json`
  declares MIT, the change is committed with a clean worktree, and a codex ask-judge that the confirmation
  cites real evidence (not a bare "done!").

Run: `st2 eval ./cells/license-mit-codex/`.

Free preflight: `bin/check-codex-native.sh cells/license-mit-codex` and
`bin/check-codex-reset.sh cells/license-mit-codex`.

Current 6/6 pass provenance and expected cost live in
[`../../CODEX-READINESS.md`](../../CODEX-READINESS.md).
