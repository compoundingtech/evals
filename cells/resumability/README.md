# resumability (Arm D) — `st launch` resumes the pinned session by default

The reboot migration brings every agent back up by **preserving its `.claude-session-id`** so it **resumes** (keeps
its context) rather than restarting from scratch. This cell is the regression guard for that guarantee: it proves
`st launch` **RESUMES the pinned session by default** and that **`--fresh`** is a clean opt-out.

## What it proves (deterministic — no live agent, no box)

`st launch --dry-run` prints the generated `claude` command without launching. The probe runs it two ways against
a pinned `.claude-session-id`:
- **default** → the command carries **`--resume <pinned-sid>`** (the agent resumes its context).
- **`--fresh`** → the command **omits `--resume`** (a genuinely fresh context; must rehydrate from git+bus), and
  the pinned `.claude-session-id` is **left UNCHANGED** (—fresh is one-off; the next non-fresh launch resumes).

If default launch stopped resuming, every agent would silently lose context at the reboot; if `--fresh` clobbered
the pin, the opt-out would be a one-way door. Both are the exact failure modes this gates.

It **complements restart-continuity**: that cell tests COLD-restart durable-state reconstruction (the `--fresh`
side); this tests the **RESUME** side — the default, migration-critical path. Ties to the convoy-up capstone's
respawn-**resume** gate.

## Run it

```sh
fixture/setup-sandbox.sh $SB     # agent cwd + a pinned .claude-session-id + CONTEXT.md
fixture/probe.sh $SB            # st launch --dry-run: default (resume) + --fresh arms + pin before/after
fixture/grade.sh $SB           # --resume present / omitted + pin preserved
```

Deterministic (dry-run) — runs anywhere. The **behavioral headline** (a resumed agent still knows CONTEXT.md's
token; a `--fresh` one rehydrates) is a live add-on that rides the box. Caps: `claude,st,pty,git`.
