# compose-global-skill — global (user-level) skills fire through a compose

**Discriminates:** does a **GLOBAL** (user-level, `~/.claude/skills`) skill — which convoy does *not* put in the
repo or the persona overlay — still get **called** in an agent composed into a repo? i.e. does convoy's setup
shadow/break the user's global-skill environment? (held-out)

**Capabilities required:** `claude,st,pty,git`. The live arm additionally
needs a supported global skill already installed (e.g. `xcodebuildmcp-cli`); else it skips-with-reason.

## What it proves (Nathan's mandate)

A composed agent must keep the user's global skills. This is the distinct case from
[`compose-config-load`](../compose-config-load/README.md) (repo-local skill): the skill lives at the **user/global**
level, and we prove the compose doesn't shadow it.

## Two tiers

- **NO-SHADOW (box-free, the provable heart — this is what the st2 folder-eval ships):** compose (`st2 render-agent`)
  into a repo and prove the compose does **not** relocate the config dir (no `CLAUDE_CONFIG_DIR` in the rendered
  `agent.kdl`), disable skills (no `--config-dir`/`--disable-slash-commands` in the seat command), or scope them away
  (`settings.local.json` is hooks-only, touching no skill key) — and writes **no workspace `.claude/skills`** to mask
  them — so the user's `~/.claude/skills` stay discoverable. Every judge is **mutation-valid** (each provably bites
  its own shadow). Proven live: 5/5 PASS.
- **GLOBAL-SKILL-FIRES (live, read-only — deferred, skips-with-reason):** take an existing `~/.claude/skills` skill
  (`xcodebuildmcp-cli`), compose an agent into a throwaway repo that lacks it, on the **default config dir** (real
  auth). Kick it with a **domain** question that never names the answer — *"what executable for iOS/Xcode
  build/test/run?"* — and assert it answers **`xcodebuildmcp`**, a distinctive string from the skill's own body. A
  **negative control** (unrelated question) must not emit it. Needs an installed global skill → not in the committed
  eval (the deterministic no-shadow core carries the proof).

## Critical isolation

The eval only **reads** `~/.claude/skills` (a fake-HOME stand-in in the folder-eval) — it never installs or writes a
global skill. A held-out judge hard-gates that the skills dir is byte-identical before/after the compose.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/compose-global-skill/     # git-init a throwaway repo → seed a fake-HOME global skill → render-agent → judge
```

Team-less + deterministic. `fixture/compose.sh` runs as the eval's `run { step "compose" }`; four held-out
`judges/` inspect the rendered artifacts (no config relocation · additive settings + mutation-valid · no workspace
skills shadow · global skills untouched). Caps: `claude` (via `st2 render-agent`), no live agent needed.
