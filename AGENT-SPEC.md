# Canonical st2 agent specification

This is the sole agent-authoring specification for this repository. It is pinned to st2
[`c6846f6239329f0803142afc06c15a07b93937c1`](https://github.com/compoundingtech/st2/commit/c6846f6239329f0803142afc06c15a07b93937c1)
(`0.1.0`, source `c6846f6`). It documents the hand-authored KDL accepted at that commit. Do not infer
additional fields or commands from older corpus fixtures.

st2 runs long-lived `service` agents made of interactive `pty` tasks and terminal-free `exec` tasks.
`service` is the only supported type and the default. Eval jobs use the separate folder-eval contract.
`role` is metadata only: it has no execution, scheduling, shepherding, or reconciliation behavior.
Scheduled work is not implemented; the reserved `schedule` node fails validation.

Hooks, personas, models, harness selection, and permissions are not special agent grammar. Authors express
them through task commands, environment, and generic `render` operations.

## Discovery, identity, and host

The conventional declaration lives at:

```text
<catalog>/agents/<host>/<identity>/agent.kdl
```

For `agent.kdl`, the parent directory supplies the default identity and its parent supplies the default host.
A non-generic `<identity>.kdl` takes identity from the filename stem and host from its parent. An explicit
positional identity, child `identity`, or child `host` wins over the path; child `identity` wins over the
positional identity. Content/path mismatches are validation warnings.

One KDL file may contain multiple top-level `agent` nodes; other top-level nodes are ignored. The bus identity
is `<host>.<identity>`. Hostless declarations resolve to the host selected by the runner. Canonical fleet
catalogs declare `host` and use a matching folder.

The catalog owns declarations, templates, logs, PTY registry, and flat native bus resources. The workspace
owns product work. Shipped declarations must not contain a developer's absolute paths, hostname, or username.

## Complete declaration shape

```kdl
agent "<identity>" {
  identity "<identity>"
  host "<host>"
  role "worker"
  type "service"
  workspace "/absolute/workspace/or/$CATALOG/path"
  supervisor "<host>.<supervisor-identity>"
  retired #false
  keep #false
  lifecycle "service"

  restart {
    attempts 3
    interval "60s"
    delay "0s"
    mode "delay"
  }

  env {
    ST_AGENT "<host>.<identity>"
  }

  argv "<interactive-harness>" "<argument>"
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
| `identity "…"` | Overrides the positional/path-derived identity. |
| `host "…"` | Execution host. The canonical folder path and content should agree. |
| `role "…"` | Optional metadata with no execution behavior. |
| `type "service"` | Optional; `service` is the only accepted value and the default. |
| `workspace "…"` | Default working directory. It must be absolute or `$CATALOG`-rooted. |
| `supervisor "…"` | Optional bare identity or full bus id for crash-loop routing. |
| `retired #true` | Decommission the declaration on the next reconciliation. Edit this flag; do not delete a live declaration to retire it. |
| `keep #true` | Freeze dead evidence and suppress collection/restart for every task; retirement still stops live tasks. |
| `lifecycle "service"|"adopt-only"` | Reconciliation policy for the compact task. Explicit tasks declare their own policy. |
| `restart { … }` | Optional service restart policy. |
| `env { KEY "value" }` | Environment inherited by the compact agent task and sidecars. |
| `argv "program" "arg"…` | Preferred compact interactive task named `agent`; direct program invocation with preserved argument boundaries. |
| `command "…"` | Compact interactive shell task named `agent`; use only when shell syntax is intentional. |
| `ding` | Compact native DING sidecar named `ding`. |
| `pty "name" { … }` | Explicit interactive task. |
| `exec "name" { … }` | Explicit non-interactive task. |
| `render { … }` | Ordered, pre-boot workspace materialization. |

Canonical declarations normally omit `type`. Unknown non-render children may be ignored; that is not
extension syntax, and required behavior must never depend on them. `schedule` is explicitly reserved and
rejected. Unknown render directives are errors.

The restart defaults are 3 attempts per 60 seconds, no delay, and `mode "delay"`. Durations accept bare
seconds or `ms`, `s|sec|secs`, `m|min|mins`, `h|hr|hrs`, and `d|day|days`. `mode "delay"` keeps retrying with
the window reset; `mode "fail"` parks the task after attempts are exhausted and sends one best-effort
crash-loop message to `supervisor`. Invalid restart subfields currently fall back to defaults; authors must not
rely on that permissiveness.

## Compact and explicit tasks

The canonical compact pair uses direct argv:

```kdl
argv "<harness>" "<argument>"
ding
```

lowers to an interactive `pty "agent"` and a non-interactive `exec "ding"` sidecar. Do not declare
both compact `argv` and compact `command`; do not combine either compact launch with `pty "agent"`;
and do not declare both `ding` and `exec "ding"`.

The compact task has id equal to the agent bus id, tag `role=agent`, and inherited agent environment. The
derived DING task has id `<bus-id>.ding` and inherited environment. A service is runnable only when at least
one authored task has exactly one `argv` or `command`; `argv` must have a non-empty program element. The
derived sidecar alone is insufficient, including on a retired declaration. Task names are sorted lexically
after lowering.

Use explicit tasks only when the agent needs an additional managed process or task-specific
configuration:

```kdl
pty "agent" {
  id "<host>.<identity>"
  argv "<interactive-harness>" "<argument>"
  cwd "/absolute/workspace/or/$CATALOG/path"
  keep #false
  lifecycle "service"
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
  lifecycle "adopt-only"
  tags purpose="fixture"
  env {
    EXAMPLE "value"
  }
}
```

Each explicit task supports only `id`, `argv`, `command`, `cwd`, `keep`, `lifecycle`, `tags`, and `env`.
A nameless task, empty `argv`, or task carrying both `argv` and `command` is a validation error. Agent-level
environment is parsed before tasks and inherited independent of declaration order; task-level values override
it. A missing `cwd` falls back to agent workspace, then the spec directory.

`argv` resolves a bare element zero through the task environment's `PATH`, expands st2 environment references
in each element, preserves argument boundaries, and launches the program directly without a shell. `command`
is opaque shell source run verbatim under `sh -c`; use it only for intentional shell behavior such as pipes,
redirections, compound commands, or shell expansion. Writing `exec` inside `command` can remove the inner
shell after it interprets that source, but it does not turn the declaration into direct argv. Interactive
harnesses belong in `pty`; terminal-free daemons and helpers belong in `exec`.

Interactive tasks run detached through the PTY runtime with stable lifecycle ids. Exec tasks allocate no
terminal, run in their own detached process group, append diagnostics below `<catalog>/logs/`, and retain one
bounded previous log generation. On systemd Linux each task uses its own transient scope. A stopped supervisor
does not implicitly stop tasks; later reconciliation adopts them. Explicit network teardown or retirement is
what stops them.

## Environment and expansion

Expansion recognizes `$VAR`, `${VAR}`, and `$$` for a literal dollar. Unset variables remain literal. Task
environment values, tags, cwd, and each direct argv element expand before spawn; command remains opaque for
its `sh -c`.

st2 defaults `CATALOG` and `ST_ROOT` to the catalog. Effective `PTY_ROOT` is a non-empty ambient value or
`<catalog>/pty`; authored task environment cannot override it. st2 supplies `ST_HOOKS` only when an installed
hook root resolves. PTY tasks default `TERM=xterm-256color`, which task environment may override. A declared
supervisor injects `ST_SUPERVISOR`; without one, that key is removed.

Authors should declare `ST_AGENT "<host>.<identity>"`. st2 does not inject it into arbitrary task environment,
although render expansion always provides the bus id.

Validation requires literal workspace/cwd values to be absolute or `$CATALOG`-rooted. Missing catalog-rooted
paths are errors. Missing external absolute paths are warnings only for the selected local host; remote-host
filesystem presence is not evaluated locally.

## Render contract

`render` operations run in declaration order:

- `copy "<source>" "<workspace destination>"` resolves relative sources catalog-first, then relative to the
  spec directory; absolute sources are accepted.
- `file "<destination>" "<content>"` writes expanded content. A `content "…"` child may carry content instead.
- `json-upsert "<destination>" "<JSON value>"` deep-merges objects, replaces arrays/scalars, and writes pretty
  JSON plus a newline. A `content` child may carry the JSON.
- `ensure-line "<destination>" "<line>"` adds one line idempotently.
- `git-exclude "<path>"…` adds workspace-local excludes without changing the committed
  `.gitignore`.

A non-empty plan requires an existing workspace. Destinations expand, must be non-empty and workspace-relative,
and cannot be absolute or contain `..`. `copy`, `file`, `json-upsert`, and `ensure-line` are boot-gating;
`git-exclude` is advisory and runs afterward.

Materialization simulates all content changes before writing and refuses a real change to a Git-tracked target.
A byte-identical tracked target is safe; untracked and non-Git targets are writable. Git inspection fails
closed when a workspace looks like a worktree but cannot be inspected. If a render operand actually references
`$ST_HOOKS`, materialization verifies the installed hook receipt; there is no implicit hook installation or
refresh.

Render expansion begins with catalog/runtime values and `ST_AGENT=<bus-id>`, then applies environment from the
task named `agent`. Network startup materializes active declarations for the selected host before
reconciliation; retired and other-host declarations are skipped. A gating failure suppresses only that agent.
Prefer a catalog-owned `.st2/` overlay and locally excluded tool loaders.

## Validation, health, and lifecycle

Canonical validation is:

```sh
st2 validate --catalog "$CATALOG" --host <host> --strict
```

Structural validation covers the entire synced fleet. External path presence and overlay-import lint are scoped
to the selected host; without `--host`, the machine's short hostname is selected. Errors include parse or
identity failure, unsupported type/schedule, nameless tasks, duplicate bus id, no authored command, unsafe or
missing paths, malformed render operations, and missing copy sources. Warnings include content/path mismatch,
an absent supervisor address, selected-host external paths missing locally, and dangling Claude imports.
`--strict` turns warnings into failure. `--json` emits stable issue metadata and totals.

Health checks accept either a live foreign host-lock owner or the default manual/no-lock mode. An explicit
supervisor requirement makes a missing live lock fail; a stale lock always fails. Active declarations require
their tasks alive and presence fresh. Retired declarations require all task records absent. The PTY runtime
probe closes stdin and is bounded at two seconds; timeout is reported as a failed readable-runtime check, not
misclassified as an empty registry.

Reconciliation is per task:

- active and alive: adopt;
- missing service task: launch only that task;
- dead non-keep service task: preserve bounded diagnostics, collect, and restart according to policy;
- dead keep: freeze evidence without collection or restart;
- missing or dead `adopt-only` task: report `held` without collection, replacement, or launch;
- retired and live: stop even when keep is set;
- retired and dead non-keep: final collection;
- unrendered or unrunnable: do not launch.

`lifecycle "adopt-only"` is a migration fence, not a restart policy. st2 may adopt an already-live generation
but may not create a missing generation or reap and replace a dead one. Declare it at agent level for the
compact task or inside each applicable explicit task. Explicit tasks that omit it independently default to
`service`; they do not inherit the compact-task policy. Deliberately restore `service` (or remove the field)
to authorize normal launch/replacement. `retired #true` is the separate teardown authority and takes
precedence.

`role` has no branch in lifecycle behavior. `supervisor` is used for `ST_SUPERVISOR` and best-effort crash-loop
routing. New exact Codex launches require verified installed hooks and workspace pretrust; already live/adopted
Codex tasks are not stopped by that launch gate.

## Native bus, DING, and presence

Message filenames are stable `<unix-ms>-<rand6>.md`. An archive receipt with the same filename shadows and
idempotently clears a restored inbox copy. New post-start unread work sends:

```text
[DING] new st2 message: [id:<rand6>] <subject> (from <sender>); check your inbox
```

Subject and sender are normalized to one bounded printable line. Delivery is one bracketed-paste PTY send,
500 ms, then Return. DING does not inspect terminal pixels or classify modal state.

Arrivals remain FIFO. `busy` and `away` do not suppress delivery; only fresh `dnd` does. Non-DND presence is
refreshed every five minutes, while abandoned DND ages to derived `unknown` after 15 minutes and delivery
resumes. Failed PTY sends retain the queue head. Startup backlog produces one generic unread-work DING rather
than replaying every message. The sidecar waits for initial target registration and exits after three
consecutive liveness misses once the target was observed alive.

Settable presence is `offline`, `available`, `busy`, `away`, or `dnd`; `unknown` is derived and cannot be set.

## Claude declaration

```kdl
agent "<identity>" {
  host "<host>"
  role "worker"
  workspace "<workspace>"
  env {
    ST_AGENT "<host>.<identity>"
  }

  argv "claude" "--model" "claude-sonnet-5" "--effort" "medium" "--permission-mode" "bypassPermissions" "<boot prompt>"
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

  argv "codex" "--model" "gpt-5.6-sol" "-c" "model_reasoning_effort=\"medium\"" "--dangerously-bypass-approvals-and-sandbox" "--dangerously-bypass-hook-trust" "<boot prompt>"
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

## Folder-eval projection

The folder-eval grammar preserves its `team`, `eval`, kickoff, timeout, and held-out judge shape. Its
agent projection supports `workspace`, `supervisor`, `env`, `command`, explicit `exec`, and bare
`ding`; it does not accept a catalog `render` block. For that grammar, `eval { copy … }` and a
deterministic pre-boot materializer must place the equivalent harness files in each declared
workspace:

- Claude: `CLAUDE.md` loading `PERSONA.md`, plus the canonical `.claude/settings.local.json`.
- Codex: `AGENTS.md`, plus the canonical `.codex/hooks.json`; the command must trust those hooks.

`bin/check-harness-contract.sh` enumerates every model agent from every maintained root KDL,
materializes only the known offline fixture builders, and compares each hook file byte-for-byte with
`harness/`. `bin/check-event-first.sh` separately requires one cold-start inbox drain followed by
native DING wakeups. Structured exceptions are in `evidence/harness-exclusions.tsv`.

## Minimum and exhaustive authoring examples

At `agents/example/worker/agent.kdl`, path-derived identity and host make this the smallest valid service:

```kdl
agent { argv "true" }
```

At the pinned source it validates as one agent with zero errors and warnings. Production declarations should
normally make identity, host, `ST_AGENT`, workspace, and the real harness command explicit.

The complete declaration, compact pair, explicit PTY/exec blocks, restart policy, and render block earlier in
this document collectively exercise every implemented authoring field. Before validating/materializing the
example, create every `$CATALOG`-rooted workspace it names.

## Free authoring gate

These commands parse and materialize without starting a model agent:

```sh
st2 validate --catalog "$CATALOG" --host <host> --strict
st2 up --catalog "$CATALOG" --host <host> --materialize-only
```

Inspect the declaration, every referenced template, and every workspace destination before the
materialization command. Materialization is byte-idempotent and does not imply hook installation. Starting
the network is a separate, explicitly authorized action.

For source `c6846f6239329f0803142afc06c15a07b93937c1`, the accepted artifact is the immutable Nix package:

- source `flake.lock` byte SHA256
  `aa547f85b21a8a8787adaa9f2a3ad37d55246d355248388e2ec38bd85a830141`;
- derivation `/nix/store/nrhfzsarya6ny7wdmy64i9vwgax965a8-st2-0.1.0.drv`;
- output `/nix/store/z4wj1y20wq00n02gpknnz45fdi2kyc7h-st2-0.1.0`, NAR
  `sha256-w3OSHKt96U0aWMzW2FHom6Ii1NvikdXqmJ6wJ1xGJNA=` (5,147,208 bytes);
- version prefix `st2 0.1.0+c6846f6` and packaged executable SHA256
  `25276f30a9cfb287e1a9f72318fada2936402343e958160d46a0a7270ab2db2b`.

`bin/check-st2-package-provenance.sh` verifies the whole chain and selects that exact binary rather than an
ambient `st2`. Its mutation gate rejects a same-version substitute. `bin/check-st2-pin-consistency.sh` keeps
this active spec, the README, and executable preflight aligned. `bin/check-corpus.sh` runs semantic validation
and every model-free gate with the pinned package before an eval may run.
