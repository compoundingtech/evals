# Canonical st2 agent specification

This is the sole agent-authoring specification for this repository. It is pinned to st2
[`25d8371a110d5310a1c94ce4537cea1ddbc1fb6c`](https://github.com/compoundingtech/st2/commit/25d8371a110d5310a1c94ce4537cea1ddbc1fb6c)
(`0.1.0 (25d8371)`). It documents the hand-authored KDL accepted at that commit. Do not infer
additional fields or commands from older corpus fixtures.

An agent declaration lives at:

```text
<catalog>/agents/<host>/<identity>/agent.kdl
```

The catalog owns declarations and template inputs. The workspace owns product work. st2 supplies
`CATALOG`, flat native `ST_ROOT`, local `PTY_ROOT`, `ST_AGENT`, and `ST_HOOKS` to managed tasks.
Shipped declarations must not contain a developer's absolute paths, hostname, or username.

## Complete declaration shape

```kdl
agent "<identity>" {
  host "<host>"
  role "worker"
  workspace "/absolute/workspace/or/$CATALOG/path"
  supervisor "<host>.<supervisor-identity>"
  retired #false
  keep #false

  restart {
    attempts 3
    interval "60s"
    delay "0s"
    mode "delay"
  }

  env {
    ST_AGENT "<host>.<identity>"
  }

  command #"<interactive harness command>"#
  ding

  render {
    copy "_templates/source" ".st2/destination"
    file ".st2/example.txt" "literal content"
    json-upsert ".tool/settings.json" #"{"owned":{"key":"value"}}"#
    ensure-line ".tool/rules/st2.md" "@../../.st2/PERSONA.md"
    git-exclude ".st2/" ".tool/rules/st2.md" ".tool/settings.json"
  }
}
```

Supported agent children are:

| Node | Meaning |
|---|---|
| `host "…"` | Execution host. The canonical folder path and content should agree. |
| `role "…"` | Optional roster/shepherding metadata. |
| `workspace "…"` | Default working directory. It must be absolute or `$CATALOG`-rooted. |
| `supervisor "…"` | Optional supervisor bus identity for crash escalation. |
| `retired #true` | Decommission the declaration on the next reconciliation. Edit this flag; do not delete a live declaration to retire it. |
| `keep #true` | Exempt every task in the declaration from garbage collection. |
| `restart { … }` | Optional service restart policy. |
| `env { KEY "value" }` | Environment inherited by the compact agent task and sidecars. |
| `command "…"` | Compact interactive task named `agent`. |
| `ding` | Compact native DING sidecar named `ding`. |
| `pty "name" { … }` | Explicit interactive task. |
| `exec "name" { … }` | Explicit non-interactive task. |
| `render { … }` | Ordered, pre-boot workspace materialization. |

`service` is the only supported job type and is the default, so canonical declarations omit `type`.
Unknown children may be ignored by the runner; that is not extension syntax. A declaration must not
use ignored fields to express required behavior.

The restart defaults are 3 attempts per 60 seconds, no delay, and `mode "delay"`. Durations accept
`ms`, `s`, `m`, `h`, or `d` (a bare integer means seconds). `mode "delay"` keeps retrying with the
window reset; `mode "fail"` parks the task after the attempts are exhausted and surfaces the crash.

## Compact and explicit tasks

The canonical compact pair:

```kdl
command #"<harness command>"#
ding
```

lowers to an interactive `pty "agent"` and a non-interactive `exec "ding"` sidecar. Do not declare
both `command` and `pty "agent"`, or both `ding` and `exec "ding"`.

Use explicit tasks only when the agent needs an additional managed process or task-specific
configuration:

```kdl
pty "agent" {
  id "<host>.<identity>"
  command #"<interactive harness command>"#
  cwd "/absolute/workspace/or/$CATALOG/path"
  keep #false
  tags role="agent" purpose="subject"
  env {
    ST_AGENT "<host>.<identity>"
  }
}

exec "helper" {
  id "<host>.<identity>.helper"
  command #"exec ./long-running-helper"#
  cwd "/absolute/workspace/or/$CATALOG/path"
  keep #false
  tags purpose="fixture"
  env {
    EXAMPLE "value"
  }
}
```

Each explicit task supports only `id`, `command`, `cwd`, `keep`, `tags`, and `env`. Agent-level
environment is inherited, then task-level values override it. Commands run through `sh -c`.
Interactive harnesses belong in `pty`; terminal-free daemons and helpers belong in `exec`.

## Render contract

`render` operations run in declaration order:

- `copy "<catalog source>" "<workspace destination>"` copies a catalog-owned template.
- `file "<destination>" "<content>"` writes literal content. A `content "…"` child may carry the
  content instead of the second positional string.
- `json-upsert "<destination>" "<JSON object>"` deep-merges JSON while retaining unrelated keys.
- `ensure-line "<destination>" "<line>"` adds one line idempotently.
- `git-exclude "<path>"…` adds workspace-local excludes without changing the committed
  `.gitignore`.

`copy`, `file`, `json-upsert`, and `ensure-line` are boot-gating. `git-exclude` is advisory.
Materialization simulates all content changes before writing and refuses a real change to a
Git-tracked target. A byte-identical tracked target is safe; untracked and non-Git targets are
writable. Prefer a catalog-owned `.st2/` overlay and tool loader files that are excluded locally.

## Claude declaration

```kdl
agent "<identity>" {
  host "<host>"
  role "worker"
  workspace "<workspace>"
  env {
    ST_AGENT "<host>.<identity>"
  }

  command #"exec claude --model claude-sonnet-5 --effort medium --permission-mode bypassPermissions '<boot prompt>'"#
  ding

  render {
    copy "_templates/<host>.<identity>.persona.md" ".st2/PERSONA.md"
    copy "_templates/bus.st2.md" ".st2/bus.md"
    ensure-line ".claude/rules/st2.md" "@../../.st2/PERSONA.md"
    ensure-line ".claude/rules/st2.md" "@../../.st2/bus.md"
    json-upsert ".claude/settings.local.json" #"""
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "async": true,
            "asyncRewake": true,
            "command": "$ST_HOOKS/claude-session-start.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$ST_HOOKS/claude-pre-compact.sh"
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$ST_HOOKS/claude-stop-failure.sh"
          }
        ]
      }
    ]
  }
}
"""#
    git-exclude ".st2/" ".claude/rules/st2.md" ".claude/settings.local.json"
  }
}
```

The persona and bus templates remain catalog-owned. The loader and hooks are additive. Every current
Claude launch explicitly selects `claude-sonnet-5` at medium effort; no launch may inherit the
operator's model or effort default.

## Codex declaration

```kdl
agent "<identity>" {
  host "<host>"
  role "worker"
  workspace "<workspace>"
  env {
    ST_AGENT "<host>.<identity>"
  }

  command #"exec codex --model gpt-5.6-sol -c model_reasoning_effort="medium" --dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust '<boot prompt>'"#
  ding

  render {
    copy "_templates/<host>.<identity>.AGENTS.md" "AGENTS.md"
    json-upsert ".codex/hooks.json" #"""
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$ST_HOOKS/codex-session-start.sh",
            "timeout": 5,
            "statusMessage": "Restoring st2 context"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$ST_HOOKS/codex-pre-compact.sh",
            "timeout": 5,
            "statusMessage": "Checkpointing st2 context"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$ST_HOOKS/codex-stop.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
"""#
    git-exclude "AGENTS.md" ".codex/hooks.json"
  }
}
```

The catalog-owned `AGENTS.md` template contains the persona and bus contract together. Every current
Codex launch explicitly selects `gpt-5.6-sol` at medium reasoning effort.

## Free authoring gate

These commands parse and materialize without starting a model seat:

```sh
st2 validate --strict --catalog "$CATALOG"
st2 up --catalog "$CATALOG" --host <host> --materialize-only
```

Inspect the declaration, every referenced template, and every workspace destination before the
materialization command. Starting the network is a separate, explicitly authorized action.
