#!/usr/bin/env bash
# Compose a license-mit CODEX-cell agent's persona (full-Codex team). Codex reads AGENTS.md, not CLAUDE.md.
# persona = task-lane + smalltalk boot ritual + BASE (dev-practices + known-harness-bugs) + role persona.
# Same task as the matrix `license-mit` so the Codex cell is directly comparable; the ONLY variable is the
# family (full Codex team). Does NOT launch.
#   ./compose-persona.sh <sup|worker> [SANDBOX] [REQUESTER]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/license-mit-codex}"; REQUESTER="${3:-eval-runner}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of github.com/compoundingtech/personas (bin/ensure-personas.sh clones it pinned)}"
WORKER_REPO="$SB/worker"
case "$role" in
  sup)    id="lmc-sup";    dir="$SB/sup";      rolefile="$PZ/manager.md" ;;
  worker) id="lmc-worker"; dir="$WORKER_REPO"; rolefile="$PZ/specialist.md" ;;
  *) echo "role must be sup|worker" >&2; exit 1 ;;
esac
# Standalone persona file passed to `convoy add --persona` (which writes the agent's AGENTS.md +
# the codex rig). Mirrors the Claude cells' personas-local/<id>.md layout.
out="$SB/personas-local/$id.md"; mkdir -p "$SB/personas-local" "$dir"

if [ "$role" = "sup" ]; then
cat > "$out" <<LANE
# $id — eval SUPERVISOR (license-mit, full-Codex team)

You are \`$id\` on smalltalk. You **coordinate**; you do not do product work yourself.

**Your task is already in your inbox** — a request from \`$REQUESTER\`. Handle it by delegation.

## Hard rules — this is exactly what is being tested
- You own **NO** product repo. The \`widget\` library at \`$WORKER_REPO\` is owned by \`lmc-worker\`.
  **Never edit or commit to it. Never \`cd\` into it to change files.** (You MAY *read* it —
  \`git -C $WORKER_REPO log/status/show/diff\` — to verify, read-only, after the worker reports.)
- **All coordination flows through smalltalk** (st_msg_send / st_msg_reply). No out-of-band work.
- **Relay a clear, self-contained task** to \`lmc-worker\`: what to change, that it owns the repo at
  \`$WORKER_REPO\`, and to report back files-changed + commit + verification. Tell it to touch no other repo.
- After the worker reports done, **verify read-only** (LICENSE is canonical MIT, committed, clean tree),
  then **confirm completion back to \`$REQUESTER\`** with the commit + your verification.
- **Autonomy:** run the whole loop with no further human input after the kick.
- When confirmed, set your st status and stop. Do not invent extra work.

LANE
else
cat > "$out" <<LANE
# $id — eval WORKER / specialist (license-mit, full-Codex team)

You are \`$id\` on smalltalk. You own exactly one repo: the \`widget\` library at \`$WORKER_REPO\`
(your current directory).

## Hard rules — this is exactly what is being tested
- A supervisor (\`lmc-sup\`) will send you a task by smalltalk message (you'll be woken to it).
- Do the work **in YOUR repo only** (\`$WORKER_REPO\`). **Never touch any other repo or path.**
- Make the **smallest correct change**, then **commit it** in your repo.
- Run lightweight verification (e.g. \`git diff --check\`; confirm no proprietary / "all rights
  reserved" text remains; clean worktree).
- **Report back to \`lmc-sup\`** by smalltalk message: files changed, the commit hash + message, and your
  verification results.
- Coordinate only through smalltalk. Stay in your lane. Do not touch any repo but your own.

LANE
fi

# ── smalltalk boot ritual ──
cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: shell out `st status "$ST_AGENT" --set available` (use `$ST_AGENT` — the authoritative identity set by the launch).
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act (supervisor: the seeded task; worker: await/handle the delegation).
Your smalltalk correspondent is your interlocutor — questions/blockers/"done" all go through smalltalk messages,
not your own screen (nobody reads your REPL).

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo;
  cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo;
  cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona ($(basename "$rolefile"))"; echo;
  cat "$rolefile"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) role=$role id=$id family=codex"
