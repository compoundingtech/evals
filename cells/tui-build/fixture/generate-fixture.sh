#!/usr/bin/env bash
# Frozen SYNTHETIC smalltalk network for the tui-build cell (tests + hermetic grading).
# Point ST_ROOT at the output and the viz's `st agents --enrich --json` + message-dir reads
# render this reproducible, fully-invented network. See ../task.toml.
#
#   ./generate-fixture.sh [OUT_DIR]   # default: ./smalltalk (next to this script)
#
# IMPORTANT — run this at RENDER/EVAL time, not once-and-commit. `st` derives the `unknown`
# status from a status-file mtime older than ~15 min, so this sets the "live" agents' mtimes to
# now and the one intentional stale agent far in the past. git doesn't preserve mtimes, so
# committed output would show everyone as fresh. The generator (deterministic content) is the
# source of truth; materialize right before you render.
#
# The roster is invented (no real network) but shaped like a real team (a human + a chief-of-staff
# + specialists) so the tree view has natural structure — while deliberately exercising the
# usability edge cases a good reviewer must catch:
#   - `away`  : NOT in the seed proto's status union — does the built UI render it, or drop it?
#   - inbox 12: overflow — does the list truncate / the badge stay legible?
#   - `dnd` / `offline` : less-common states with distinct affordances
#   - empty inbox : the empty state
#   - `unknown` via stale mtime : the derived/degraded state
set -euo pipefail

OUT="${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/smalltalk"}"
rm -rf "$OUT"; mkdir -p "$OUT"

# agent <id> <status>  -> make dir + inbox/archive + status file (mtime=now)
agent() { local id="$1" st="$2"; mkdir -p "$OUT/$id/inbox" "$OUT/$id/archive"; printf '%s\n' "$st" > "$OUT/$id/status"; }

# msg <agent> <box:inbox|archive> <ms> <suffix> <from> <priority> <subject>  (body on stdin)
msg() {
  local id="$1" box="$2" ms="$3" sfx="$4" from="$5" prio="$6" subj="$7"
  { printf -- '---\nfrom: %s\nsubject: "%s"\npriority: %s\n---\n' "$from" "$subj" "$prio"; cat; } \
    > "$OUT/$id/$box/${ms}-${sfx}.md"
}

# ── the invented network ──────────────────────────────────────────────────
agent river   available   # the human / principal
agent atlas   available   # chief-of-staff / supervisor
agent nova    busy        # mid-task
agent sol     available   # a lead
agent vega    dnd         # heads-down
agent orion   available   # overflow inbox below
agent lyra    away        # EDGE: `away` isn't in the seed proto's status union
agent echo    offline     # EDGE: offline
agent zephyr  available   # mtime forced stale below -> derived `unknown`

# ── messages (give the preview pane real content) ─────────────────────────
msg river inbox 1782928800000 r1a2b3 atlas normal "morning plan — the viz is looking real" <<'EOF'
Walked the overnight work. The two views share one data layer now; kicking the usability pass next.
EOF

msg atlas inbox 1782928200000 a1d4e5 sol high "shared data layer landed — need the 'where the preview reads from' call" <<'EOF'
network.ts reads `st agents --enrich --json` + the message dir. Confirm the preview pane reads from the same frozen dir, not a live peek?
EOF
msg atlas inbox 1782928500000 a2f6a7 orion normal "cards view green + integrated, ready to review" <<'EOF'
Card grid + preview pane done, tests green. Held for your integration walk.
EOF

msg sol inbox 1782927900000 s1a8b9 atlas normal "brief — wire tree view to the shared layer" <<'EOF'
Take the tree+preview seed and point it at network.ts. Keep the preview pane; add the empty-inbox + overflow states.
EOF

msg lyra inbox 1782927600000 l1c2d3 atlas normal "brief — usability pass, human-centered" <<'EOF'
Fresh eyes on both views: empty states, overflow/truncation, statuses that don't read clearly, "how do I navigate this". Find + fix.
EOF

# orion: OVERFLOW inbox (12) — exercises truncation + badge legibility.
msg orion inbox 1782920000000 o0aa01 sol normal "brief — cards layout + preview" <<'EOF'
Port the cards+preview seed onto the shared data layer. Get to a working, tested state.
EOF
for i in $(seq -w 2 12); do
  # 13-digit ms required by the message filename grammar; keep them distinct + valid.
  msg orion inbox "$((1782920000000 + 10#$i * 1000))" "o0aa$i" bot low "review nudge #$i" <<EOF
Automated: a review comment thread is waiting on item $i. (filler to exercise the overflow/truncation state)
EOF
done

# archive depth for a couple agents (preview can show recent history)
msg atlas archive 1782900000000 z1old1 river normal "get the viz to a state I can try" <<'EOF'
The agent-network viz — get it to a state I can run + read at a glance.
EOF

# ── the intentional `unknown`: force zephyr's status mtime far into the past ──
touch -t 202601010000 "$OUT/zephyr/status"

echo "fixture materialized at: $OUT"
echo "render with:  ST_ROOT='$OUT' st agents --enrich --json"
