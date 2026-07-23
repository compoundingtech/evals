# skill-inheritance — a composed worker inherits + USES user-brought skills (project + plugin union)

**Discriminates:** does a worker composed into a repo inherit the same Claude Code skill-loading a normal `claude`
session gets — the skills a user brings actually **LOAD and fire** inside the worker, as a **UNION** across scopes?
Proven on the two scopes that live **outside** the config dir (so no auth relocation and no personal-scope
pollution is needed):

- **PROJECT scope** — `repo/.claude/skills/evalskill-project`, auto-loaded because the worker's cwd **is** the repo
  (its `workspace`). No injection.
- **PLUGIN scope** — a standalone local plugin (`evalpkg`) loaded via `claude --plugin-dir` (session-only), spliced
  straight into the worker's launch command in the `.kdl`. Plugin skills are namespaced (`evalpkg:evalskill-plugin`).

## The ungameable core

Each skill's body carries a **secret token** (`SIP-…` project, `SIU-…` plugin) and tells the worker to write it to
a sentinel file (`SKILL_PROJECT.txt` / `SKILL_PLUGIN.txt`). The token lives **only** in the skill body — never in
the kick — so a sentinel bearing the right token proves that skill actually **loaded + fired** (it was otherwise
unobtainable, the plugin token especially since its dir is never named to the worker). Both firing = the worker saw
**both scopes at once** (union). Held-out judges extract each token from its SKILL.md (ground truth) and compare.

## Isolation (safe on the live box)

Project skills are cwd-local and `--plugin-dir` is documented **session-only** (it does not persist to
`~/.claude/plugins`), so the operator's personal `~/.claude` is untouched by construction — no config-dir
relocation, real auth. A held-out judge hard-gates that `~/.claude/skills` carries no `evalskill-*` and
`~/.claude/plugins` no `evalpkg` after the run.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/skill-inheritance/     # copy fixture (repo + plugin) → boot si.agent with --plugin-dir → judge
```

The whole eval is `skill-inheritance.kdl`: one worker (`si.agent`, workspace `./repo`) booted with
`--plugin-dir $CATALOG/plugin/evalpkg`; the kick asks it to invoke every `evalskill` skill and follow each one's
instructions. Three held-out `judges/` (project scope · plugin scope union · isolation). Caps: `claude`. Proven
live: 3/3 PASS (both secret tokens landed; personal scope untouched).

**Deferred (documented, auth-gated):** personal `~/.claude/skills` inheritance + same-name precedence override —
isolating an *installed* test skill needs a relocated config dir, which breaks the keychain-locked oauth.
