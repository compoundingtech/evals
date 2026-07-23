# Restore-TODO — cells removed pending a capability, to be brought back

Cells here were removed from the suite by Nathan's explicit per-cell sign-off, not retired — each is
valuable and should be **restored** once the capability it tests exists. Restore any of them from git
history: `git log --oneline -- cells/<name>` → `git checkout <commit>^ -- cells/<name>`.

## first-run  — restore when the onboarding path exists (Nathan: "add it back soon")
The stranger-onboarding + **no-leak** eval: a newcomer clones the SHA-pinned public personas repo
(read-only), runs a scripted first-run interview, and ends with a committed **private** CoS repo joined
to a fresh network — headlined by the NO-LEAK gate (nothing private leaks into the public clone). Removed
now only because st2 has no imperative onboarding/interview command yet (the workflow is: author st2 spec
files + run them). **Restore + port to the folder format once the onboarding path is built.** Highest
priority of the restorables.

---

### Removed with no restore planned (documented for provenance, not scheduled)
These test imperative st2 commands Nathan is not building (the workflow is now: author st2 spec files +
run them, capturing behaviors as evals). Restorable only if those commands are ever added:
- **convoy-add-structure** — tested `convoy add` producing a seat overlay; no `st2 add` command planned.
- **convoy-init-structure** — tested `convoy init <net>` producing the network layout; no `st2 init`.
- **convoy-init-narration** — tested `convoy init`'s narration / `--quiet` / `--json`; no `st2 init`.
