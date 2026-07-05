#!/usr/bin/env bash
# Compose an eval agent's persona = task-lane + coord boot ritual + role persona + BASE
# (dev-practices + known-harness-bugs), per FRAMEWORK.md. Writes CLAUDE.md (claude) or
# AGENTS.md (codex) into the agent's dir.
#   ./compose-persona.sh <sup|worker> <claude|codex> [SANDBOX]
set -euo pipefail
role="$1"; family="$2"; SB="${3:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"
# Requester = who sent the kick + who the supervisor confirms back to. Defaults to the harness
# (eval-runner) so the loop is fully observable + doesn't contaminate a live agent's inbox.
REQUESTER="${4:-eval-runner}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of github.com/myobie/personas (bin/ensure-personas.sh clones it pinned)}"   # canonical role/base personas (read-only)
WORKER_REPO="$SB/worker"
# Identities are overridable (env) so a cross-family REPEAT cell uses FRESH ids and never collides
# with a prior cell's coord dir. Default to the Mixed-cell names for backward compat.
SUP_ID="${SUP_ID:-mix-sup}"
WORKER_ID="${WORKER_ID:-mix-worker}"

case "$role" in
  sup)    id="$SUP_ID";    dir="$SB/sup";    rolefile="$PZ/manager.md" ;;
  worker) id="$WORKER_ID"; dir="$WORKER_REPO"; rolefile="$PZ/specialist.md" ;;
  *) echo "role must be sup|worker" >&2; exit 1 ;;
esac
case "$family" in
  claude) out="$dir/CLAUDE.md" ;;
  codex)  out="$dir/AGENTS.md" ;;
  *) echo "family must be claude|codex" >&2; exit 1 ;;
esac
mkdir -p "$dir"

# ── the task-lane addendum (authoritative; leads the file) ──
if [ "$role" = "sup" ]; then
cat > "$out" <<LANE
# $id — eval SUPERVISOR (Mixed-team license-mit run)

You are \`$id\` on smalltalk/coord. You **coordinate**; you do not do product work yourself.

**Your task is already in your inbox** — a request from \`$REQUESTER\`. Handle it by delegation.

## Hard rules — this is exactly what is being tested
- You own **NO** product repo. The \`widget\` library at \`$WORKER_REPO\` is owned by \`$WORKER_ID\`.
  **Never edit or commit to it. Never \`cd\` into it to change files.** (You MAY *read* it —
  \`git -C $WORKER_REPO log/status/show/diff\` — to verify, read-only, after the worker reports.)
- **All coordination flows through smalltalk** (coord_msg_send / coord_msg_reply). No out-of-band work.
- **Relay a clear, self-contained task** to \`$WORKER_ID\`: what to change, that it owns the repo at
  \`$WORKER_REPO\`, and to report back files-changed + commit + verification. Tell it to touch no other repo.
- After the worker reports done, **verify read-only** (LICENSE is canonical MIT, committed, clean tree),
  then **confirm completion back to \`$REQUESTER\`** with the commit + your verification.
- **Autonomy:** run the whole loop with no further human input after the kick.
- When confirmed, set your coord status and stop. Do not invent extra work.

LANE
else
cat > "$out" <<LANE
# $id — eval WORKER / specialist (Mixed-team license-mit run)

You are \`$id\` on smalltalk/coord. You own exactly one repo: the \`widget\` library at \`$WORKER_REPO\`
(your current directory).

## Hard rules — this is exactly what is being tested
- A supervisor (\`$SUP_ID\`) will send you a task by coord message (you'll be woken to it).
- Do the work **in YOUR repo only** (\`$WORKER_REPO\`). **Never touch any other repo or path.**
- Make the **smallest correct change**, then **commit it** in your repo.
- Run lightweight verification (e.g. \`git diff --check\`; confirm no proprietary / "all rights
  reserved" text remains; clean worktree).
- **Report back to \`$SUP_ID\`** by coord message: files changed, the commit hash + message, and your
  verification results.
- Coordinate only through smalltalk. Stay in your lane. Do not touch any repo but your own.

LANE
fi

# ── coord boot ritual ──
cat >> "$out" <<'BOOT'
---
## Coord boot ritual (do this first, every fresh start)
1. Set your status available: shell out `coord status <your-identity> --set available` (use $COORD_IDENTITY).
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act on what you found (the supervisor: the seeded task; the worker: await/handle the delegation).
Your coord correspondent is your interlocutor — questions/blockers/"done" all go through coord messages,
not your own screen (nobody reads your REPL).

BOOT

# ── BASE: dev-practices ──
{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo;
  cat "$PZ/dev-practices.md"; echo; } >> "$out"

# ── BASE: known harness bugs ──
{ echo '---'; echo '## BASE — known harness bugs'; echo;
  cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"

# ── role persona ──
{ echo '---'; echo "## ROLE persona ($(basename "$rolefile"))"; echo;
  cat "$rolefile"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines: lane + boot + base(dev-practices+known-harness-bugs) + role)"
