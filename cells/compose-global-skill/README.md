# compose-global-skill — global (user-level) skills fire through a compose

**Discriminates:** does a **GLOBAL** (user-level, `~/.claude/skills`) skill — which convoy does *not* put in the
repo or the persona overlay — still get **called** in an agent composed into a repo? i.e. does convoy's setup
shadow/break the user's global-skill environment? (held-out)

**Capabilities required:** `claude,convoy,st,pty,git` · run `bin/st-evals preflight`. The live arm additionally
needs a supported global skill already installed (e.g. `xcodebuildmcp-cli`); else it skips-with-reason.

## What it proves (Nathan's mandate)

A composed agent must keep the user's global skills. This is the distinct case from
[`compose-config-load`](../compose-config-load/README.md) (repo-local skill): the skill lives at the **user/global**
level, and we prove the compose doesn't shadow it.

## Two tiers

- **NO-SHADOW (box-free, the provable heart):** compose into a repo and prove the compose does **not** relocate the
  config dir (no `CLAUDE_CONFIG_DIR` in `pty.toml`), disable skills (no `--config-dir`/`--disable-slash-commands`),
  or scope them away (`settings.local.json` is hooks-only) — so the user's `~/.claude/skills` stay discoverable.
- **GLOBAL-SKILL-FIRES (live, read-only):** take an existing `~/.claude/skills` skill (`xcodebuildmcp-cli`), compose
  an agent into a throwaway repo that lacks it, on the **default config dir** (real auth). Kick it with a **domain**
  question that never names the answer — *"what executable for iOS/Xcode build/test/run?"* — and assert it answers
  **`xcodebuildmcp`**, a distinctive string from the skill's own body (a skill-less agent answers the raw tool,
  `xcodebuild`). A **negative control** (unrelated question) must not emit it. Skips-with-reason on a skill-less box.

> **Why read-only.** Isolating an *installed* test skill needs a relocated config dir, which breaks the
> keychain-locked oauth (no `ANTHROPIC_API_KEY`) — the wall `skill-inheritance` deferred personal-scope for. Nathan's
> fix: use a skill **already present**, read-only, on the default config dir — real auth, no key, no install, no
> cleanup. The assertion's rigor comes from a distinctive string in the skill body that never appears in the kick.

## Critical isolation

The eval only **reads** `~/.claude/skills` — it never installs or writes a global skill. The grader hard-gates that
the real `~/.claude/skills` is byte-identical before/after, and that no session leaks to the operator's global pty.

## Run it

Box-free: `fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`. Live: `fixture/spin.sh` then `fixture/grade.sh <SB>`
(needs a supported global skill). Zero-orphan teardown; `~/.claude/skills` verified unchanged after.

See `task.toml` for the full spec.
