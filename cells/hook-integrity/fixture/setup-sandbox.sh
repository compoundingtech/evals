#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# hook-integrity — materialize ONE launch sandbox for the SessionStart-hook diagnostic.
#
# The point of this cell is NOT a task; it is to prove — from GROUND TRUTH — that a Claude
# agent's **SessionStart hook actually FIRES** on launch (a real field failure: hooks were
# configured but silently never ran, and no eval would have caught it). We assert the hook's
# UNGAMEABLE side effect: the hook injects the agent's durable working-state (context/now.md) as
# a <context> block on the first turn. We seed now.md with a SECRET TOKEN the agent can learn NO
# other way — not in its persona, not in its repo, not in its inbox — only via that injection. If
# the hook fires, the agent sees the token and writes it to HOOK_OK.txt; if it doesn't, it can't.
#
# The SAME fixture is launched twice by run.sh: once hooks-ON (`st launch claude`) and once
# hooks-OFF (`st launch claude --no-hooks`). ON must produce the token; OFF must NOT. That
# difference IS the integrity proof — a check that passes with AND without hooks tests nothing.
#
#   ./setup-sandbox.sh [SANDBOX]        # builds ${EVAL_SANDBOX:-./.sandbox}/hook-integrity
#   HI_TOKEN=<tok> ./setup-sandbox.sh …  # use a specific token (run.sh passes the same token to both legs)
#
# Self-contained + offline: no agents launched here (that's configure-claude-agent.sh via run.sh).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/hook-integrity}"
ID="hi-agent"

# The secret token. run.sh generates ONE token and passes it to both legs via HI_TOKEN so the
# grader checks the same string; standalone (smoke gate) it self-generates. It appears ONLY in
# context/now.md below — nowhere the agent can otherwise read.
TOKEN="${HI_TOKEN:-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB"
REPO="$SB/repo"; mkdir -p "$REPO"
STR="$SB/st-root"                                    # isolated bus root for THIS leg

# ── the tiny owned repo (the agent's cwd; it writes HOOK_OK.txt here) ─────────
cat > "$REPO/README.md" <<'MD'
# hook-integrity probe repo

A throwaway repo owned by `hi-agent` for the SessionStart-hook diagnostic. The agent's only job —
if it receives one — arrives via its injected working state, not from anything in this repo.
MD
cat > "$REPO/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
PERSONA.md
DING-BUS.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI
git -C "$REPO" init -q -b main
git -C "$REPO" add -A
git -C "$REPO" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "probe repo: base"
git -C "$REPO" config user.name  "$ID"                # author-pin: if the agent commits, it's attributable
git -C "$REPO" config user.email "$ID@eval.local"
BASE="$(git -C "$REPO" rev-parse --short HEAD)"

# ── the isolated bus dir for hi-agent (context/now.md is the hook-EXCLUSIVE channel) ──
mkdir -p "$STR/$ID/inbox" "$STR/$ID/archive" "$STR/$ID/context"

# now.md: the durable working-state the SessionStart hook injects IFF it fires (and IFF fresh —
# we write it now, so mtime age ~0 << the 24h staleness gate). It carries the secret task+token.
# NOTHING else in the fixture references now.md, the token, or HOOK_OK.txt — so the token is
# reachable ONLY through the hook's injection. That is what makes the assertion ungameable.
cat > "$STR/$ID/context/now.md" <<NOW
# Current working state — $ID

You were mid-task and just resumed from your durable working state. Your task is small and you can
finish it immediately, right now, with no other steps:

**Write a file named \`HOOK_OK.txt\` in your repository (your current working directory). Its entire
contents must be exactly this single line:**

REHYDRATE-$TOKEN

Writing that file confirms you resumed from your working state. Once it is written you are done —
do not do anything else, and do not wait for further instructions.
NOW

# status seeded 'offline' so a flip to 'available' is a (soft) sign the boot ritual ran; a benign
# inbox note for the boot-drain observation. Neither hints at the token/task (ungameability).
printf 'offline\n' > "$STR/$ID/status"
{ printf -- '---\nfrom: eval-runner\nsubject: "welcome"\npriority: low\n---\n'; \
  printf 'Welcome to the network. Nothing is needed from you right now.\n'; } \
  > "$STR/$ID/inbox/1783000000000-hiwlcm.md"

# ── minimal STANDALONE persona (fed to st launch --persona) ──────────────────
# Deliberately minimal: it does NOT instruct a boot ritual and NEVER mentions now.md, context, a
# token, or HOOK_OK.txt. So any HOOK_OK.txt with the token is attributable ONLY to the hook's
# injection — not to the persona. (This is the Leg-A/B hardening the design calls for.)
mkdir -p "$SB/personas-local"
cat > "$SB/personas-local/$ID.md" <<PERSONA
# $ID — probe specialist

You are \`$ID\`, a specialist on the st network. You own exactly one repo: the one in your current
working directory. Work only inside it; never touch any other repo or path.

If you are given a task or working instructions, carry them out directly and completely, then stop.
Keep any changes minimal. Use the \`st\` CLI for any network/bus operations. There is no human
watching your terminal — do not wait for input.
PERSONA

echo
echo "SANDBOX READY: $SB   (repo base $BASE; author $ID; isolated bus $STR)"
echo "  repo/                 the owned cwd (agent writes HOOK_OK.txt here if the hook fires)"
echo "  st-root/$ID/context/now.md   the hook-exclusive working-state carrying the secret token"
echo "  personas-local/$ID.md        minimal standalone persona (no boot ritual, no token, no now.md ref)"
echo "  token (this leg): REHYDRATE-$TOKEN   [also written to $SB/.hi-token for the grader]"
printf '%s\n' "$TOKEN" > "$SB/.hi-token"    # grader reads the expected token from here
