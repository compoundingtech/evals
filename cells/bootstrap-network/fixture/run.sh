#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap-network eval — reproducible, hermetic runner.
#
# Walks a NEWCOMER (a "Alex") from zero to a working CoS network and grades
# four gates pass/fail:
#   A. init a NEW smalltalk network (fresh ST_ROOT) + bring a CoS online
#   B. CoS boot ritual: set status available + drain the inbox
#   C. CoS spawns a new specialist agent (harness bootstrap)
#   D. the two exchange a message over smalltalk, end-to-end
#
# The DELIVERABLE is the friction list: every place the documented happy path
# diverges from reality. So this script deliberately runs the DOCUMENTED path
# first at each gate — when it fails, that failure IS the finding — then applies
# the workaround and proceeds. Friction is collected and printed at the end.
#
# Hermetic: a fresh ST_ROOT under an isolated sandbox each run; NEVER the live
# network (we never fall back to the default root). No network I/O. Offline.
#
#   ./run.sh [SANDBOX_DIR]     # default: ${EVAL_SANDBOX:-./.sandbox}/bootstrap-network
#
# Exit 0 = all four gates PASS (friction may still be non-empty — friction is a
# finding, not a gate failure). Exit 1 = a gate genuinely failed.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

SANDBOX="${1:-${EVAL_SANDBOX:-./.sandbox}/bootstrap-network}"
STR="$SANDBOX/st-root"          # the fresh network root

# friction findings, collected as we go
declare -a FRICTION=()
note() { FRICTION+=("$1"); printf '  ⚠ FRICTION: %s\n' "$1"; }
gate() { printf '\n=== GATE %s ===\n' "$1"; }
pass() { printf '  ✓ PASS: %s\n' "$1"; }
fail() { printf '  ✗ FAIL: %s\n' "$1"; GATE_FAIL=1; }
GATE_FAIL=0

# Every eval command runs against the sandbox root with a CLEAN identity env:
# strip the caller's COORD_IDENTITY (HB-3 leak surface) and pass ST_AGENT per
# command. `c <agent> <args...>` runs the resolved smalltalk CLI as <agent>.
c() { local who="$1"; shift; env -u COORD_IDENTITY ST_ROOT="$STR" ST_AGENT="$who" "$BIN" "$@"; }

# ── Gate 0 (pre-flight): which binary does a newcomer actually have? ──────────
gate "0 — binary on PATH"
BIN=""
for cand in st smalltalk coord; do
  if command -v "$cand" >/dev/null 2>&1; then BIN="$cand"; break; fi
done
if [ -z "$BIN" ]; then
  fail "no smalltalk CLI on PATH (looked for: st, smalltalk, coord)"
  echo "the docs say 'st'; nothing is installed. Cannot proceed."; exit 1
fi
printf '  binary found: %s  (%s)\n' "$BIN" "$(command -v "$BIN")"
if [ "$BIN" != "st" ]; then
  note "docs/persona say \`st …\` / \`st launch\`, but the only CLI on PATH is \`$BIN\` (the pre-rename package name). A newcomer copy-pasting \`st …\` from the README/onboarding.md gets 'command not found'. (README's \`export PATH=\$PWD/bin:\$PATH\` install gives \`st\`; a box-inheritor gets \`$BIN\`.)"
fi
if ! "$BIN" --version >/dev/null 2>&1; then
  note "\`$BIN --version\` is not a command ('unknown subcommand') — no way to confirm which build you're on (e.g. that it's new enough for \`$BIN launch\`)."
fi

# fresh, hermetic sandbox
rm -rf "$SANDBOX"; mkdir -p "$SANDBOX" "$STR"

# ── Gate A: init a fresh network + bring the CoS online ───────────────────────
gate "A — init fresh network, CoS online"
# The DOCUMENTED path (onboarding.md Step 3 / README): a single `status --set`
# is claimed to lazily create the identity folder. Try it verbatim first.
if c cos status cos --set available >/dev/null 2>&1; then
  A_LAZY=1
  pass "documented single-command \`status --set available\` lazy-created the folder + set status (no manual mkdir)"
else
  A_LAZY=0
  note "onboarding.md Step 3 + README both say \`status --set available\` 'lazily creates' the agent folder; it does NOT — it exits 1: 'agent folder missing for cos — create it: mkdir -p \$ST_ROOT/cos/{inbox,archive}'. The newcomer's FIRST init command fails. The required mkdir is only documented in a different, older doc (agent-onboarding.md Step 4)."
  # workaround: the mkdir the error message demands
  mkdir -p "$STR/cos/inbox" "$STR/cos/archive"
  if c cos status cos --set available >/dev/null 2>&1; then
    pass "after \`mkdir -p \$ST_ROOT/cos/{inbox,archive}\`, \`status --set available\` works"
  else
    fail "status --set still fails after mkdir"
  fi
fi
# no network-init command exists
note "no \`$BIN init-network\` / \`$BIN onboard-agent\` command: 'init a fresh network' = set ST_ROOT + hand-mkdir each agent's {inbox,archive}. The newcomer must know the folder convention by hand. (agent-onboarding.md's own 'Forward-looking: coord onboard-agent' section proposes exactly this — still unbuilt.)"
# verify CoS is visible + available
if c cos agents --json --enrich 2>/dev/null | grep -q '"identity":"cos".*"status":"available"'; then
  pass "CoS visible in \`agents\` as available"
else
  fail "CoS not visible/available in agents"
fi

# ── Gate B: CoS boot ritual — drain the inbox ─────────────────────────────────
gate "B — CoS boot ritual (available + drain inbox)"
# seed a realistic welcome from the human, then drain as the CoS would on boot
echo "welcome to the network — glad the CoS is up" \
  | c operator message send cos --subject "welcome" >/dev/null 2>&1 \
  && pass "seed: human 'operator' messaged the CoS" \
  || fail "could not seed a welcome message"
# (observe lazy-create asymmetry: send auto-created operator's folder, status did not)
if [ -d "$STR/operator" ] && [ "${A_LAZY:-0}" -eq 0 ]; then
  note "lazy-create is INCONSISTENT across verbs: \`message send\` auto-created the sender's folder (operator/), but \`status --set\` (Gate A) refused and demanded a manual mkdir. Same 'first touch', opposite behavior — unpredictable for a newcomer."
fi
BEFORE=$(c cos message ls 2>/dev/null | grep -cE '^[0-9]{13}-')
for f in $(c cos message ls 2>/dev/null | grep -E '^[0-9]{13}-'); do
  c cos message read "$f"    >/dev/null 2>&1
  c cos message archive "$f" >/dev/null 2>&1
done
AFTER=$(c cos message ls 2>/dev/null | grep -cE '^[0-9]{13}-')
if [ "$BEFORE" -ge 1 ] && [ "$AFTER" -eq 0 ]; then
  pass "CoS drained inbox: read + archived $BEFORE message(s); inbox now empty"
else
  fail "inbox drain incomplete (before=$BEFORE after=$AFTER)"
fi

# ── Gate C: CoS spawns a specialist ───────────────────────────────────────────
gate "C — CoS spawns a specialist (harness bootstrap)"
SPEC="demo-specialist"
mkdir -p "$SANDBOX/demo-repo"
mkdir -p "$STR/$SPEC/inbox" "$STR/$SPEC/archive"   # same mkdir-first friction as Gate A
# The CoS runs `<BIN> launch claude --identity <spec>` in the specialist's repo.
# Dry-run so this eval stays cheap + offline; assert it generates a bootable
# harness AND writes the CHILD's identity into pty.toml (the HB-3 leak check).
DRY=$( cd "$SANDBOX/demo-repo" && c cos launch claude --identity "$SPEC" --dry-run 2>&1 )
if printf '%s\n' "$DRY" | grep -q "ST_AGENT = \"$SPEC\""; then
  pass "launch generates pty.toml with [sessions.claude.env] ST_AGENT = \"$SPEC\" (child identity written in — HB-3 mitigated: ST_AGENT is the preferred var, wins over an inherited COORD_IDENTITY)"
else
  fail "launch pty.toml does not set the child's ST_AGENT — HB-3 identity-leak risk"
fi
printf '%s\n' "$DRY" | grep -q 'asyncRewake' \
  && pass "launch wires the SessionStart asyncRewake boot-ritual hook" \
  || note "launch did not wire the asyncRewake hook — the boot ritual won't fire on cold start/resume"
if printf '%s\n' "$DRY" | grep -qiE '/[^"[:space:]]*smalltalk/examples/claude-code/hooks/'; then
  note "launch bakes an ABSOLUTE hook path into the generated .claude/settings.local.json (…/smalltalk/examples/claude-code/hooks/*.sh). Correct on the machine that ran launch, but brittle: if the smalltalk checkout moves — or a box-inheritor's lives elsewhere — the hook path dangles and the boot ritual silently never fires. (Also trips cos's 'don't bake machine specifics into artifacts' rule.)"
fi

# ── Gate D: end-to-end message round-trip (with an HB-3 kill-test) ─────────────
gate "D — end-to-end message round-trip"
echo "you're online — reply when you see this" \
  | c cos message send "$SPEC" --subject "hello from cos" >/dev/null 2>&1
GOT=$(c "$SPEC" message ls 2>/dev/null | grep -E '^[0-9]{13}-' | head -1)
# NB: `message read` prints its header (to/ts/from/subject) to STDERR and only
# the body to STDOUT — so attribution must be read via --json (or --raw), not by
# grepping stdout. (Captured as a DX friction below.)
if [ -n "$GOT" ] && c "$SPEC" message read --json "$GOT" 2>/dev/null | grep -qE '"from":[[:space:]]*"cos"'; then
  pass "CoS -> $SPEC delivered + read (from: cos)"
  c "$SPEC" message archive "$GOT" >/dev/null 2>&1
else
  fail "CoS -> $SPEC message not delivered/read"
fi
# HB-3 KILL-TEST: reply with COORD_IDENTITY=cos LEAKED into env and NO --from.
# If ST_AGENT wins, the received message's from: is the specialist, not cos.
echo "got it, cos — $SPEC online and reporting for duty" \
  | env ST_ROOT="$STR" ST_AGENT="$SPEC" COORD_IDENTITY=cos "$BIN" message send cos --subject "re: hello from cos" >/dev/null 2>&1
RN=$(c cos message ls 2>/dev/null | grep -E '^[0-9]{13}-' | head -1)
if [ -n "$RN" ] && c cos message read --json "$RN" 2>/dev/null | grep -qE "\"from\":[[:space:]]*\"$SPEC\""; then
  pass "$SPEC -> CoS reply delivered; from: $SPEC even with COORD_IDENTITY=cos leaked + no --from (HB-3 dead: ST_AGENT wins)"
else
  fail "reply mis-attributed or undelivered (HB-3 identity leak?)"
fi

# minor CLI-ergonomics friction observed along the way
c cos agents --enrich >/dev/null 2>&1 || note "CLI/DX papercuts: (a) \`agents --enrich\` errors 'requires --json' — no enriched HUMAN-readable output; (b) the CLI \`message\` verb set is send|ls|read|archive|thread with NO \`reply\` (reply is MCP-only) so a CLI reply is \`message send <peer>\` by hand; (c) \`message read\` prints its header (to/ts/from/subject) to STDERR and only the body to STDOUT, so scripting attribution needs \`message read --json\`/\`--raw\`."

# ── summary ───────────────────────────────────────────────────────────────────
printf '\n─────────────────────────────────────────────\n'
if [ "$GATE_FAIL" -eq 0 ]; then
  printf 'VERDICT: PASS — all 4 gates green (bootstrap works end-to-end).\n'
else
  printf 'VERDICT: FAIL — a gate failed (see ✗ above).\n'
fi
printf 'FRICTION FINDINGS: %d (the deliverable — what a newcomer hits)\n' "${#FRICTION[@]}"
i=1; for f in "${FRICTION[@]}"; do printf '  %d. %s\n' "$i" "$f"; i=$((i+1)); done
printf '─────────────────────────────────────────────\n'
exit "$GATE_FAIL"
