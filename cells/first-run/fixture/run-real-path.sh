#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run-real-path.sh — the REAL "someone can use this on their machine" chain.
#
# Extends run.sh (local zero-to-network) with the two pieces that make it the
# actual onboarding a stranger does:
#   • CONSUME the PUBLIC `personas` repo, SHA-pinned, read-only.
#   • run the FIRST-RUN INTERVIEW (scripted principal) → a working PRIVATE `cos` repo.
#
# The chain proven: stranger → clones public personas (pinned) → boots a CoS →
# fresh network so the interview runs → answers seeded by a scripted principal →
# a committed private cos repo → the CoS joins the network. Re-boot → interview SKIPS.
#
# The headline is the P3 NO-LEAK gate: the private repo carries the principal's data,
# the public personas checkout carries ZERO of it and is byte-for-byte unmodified —
# proving the public/private split (private data comes from the interview, never the
# public repo, and nothing leaks back).
#
# Hermetic + reproducible: P0 clones the public personas ONCE (needs network), pinned
# to a fixed SHA; everything else is offline + deterministic (the scripted principal
# is a fixture). The DELIVERABLE, as with run.sh, is the friction list — here about the
# interview + consumption contract.
#
#   ./run-real-path.sh [SANDBOX_DIR]
#
# Exit 0 = every gate PASS. Friction is a finding, not a gate failure.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX="${1:-${EVAL_SANDBOX:-./.sandbox}/first-run-interview}"
PERSONAS_URL="${PERSONAS_URL:-https://github.com/myobie/personas}"
# Pin the public contract to a known SHA (bump deliberately). Reproducibility = this pin.
PERSONAS_PIN="${PERSONAS_PIN:-f12458a3a0139ab31bcad7c8b3a9f5750f873a97}"
STR="$SANDBOX/st-root"     # the fresh network root
PRIV="$SANDBOX/cos"        # the PRIVATE cos repo (= the cwd where init is run)

declare -a FRICTION=()
note() { FRICTION+=("$1"); printf '  ⚠ FRICTION: %s\n' "$1"; }
gate() { printf '\n=== %s ===\n' "$1"; }
pass() { printf '  ✓ PASS: %s\n' "$1"; }
fail() { printf '  ✗ FAIL: %s\n' "$1"; GATE_FAIL=1; }
GATE_FAIL=0

BIN=""; for cand in st smalltalk coord; do command -v "$cand" >/dev/null 2>&1 && { BIN="$cand"; break; }; done
[ -z "$BIN" ] && { echo "no smalltalk CLI on PATH"; exit 1; }
c() { local who="$1"; shift; env -u COORD_IDENTITY ST_ROOT="$STR" ST_AGENT="$who" "$BIN" "$@"; }

# The scripted principal = the seeded answers a live human would give the CoS.
# (cos's decision: non-interactive interview mode — the CoS reads answers from a
# seeded source rather than driving live forms. This fixture IS that source.)
# shellcheck disable=SC1090
source "$HERE/principal-answers.env"

# ── the CoS "runs" the interview: translate the seed → the private repo, per the
#    first-run-interview.md contract. In Layer 1 the eval plays the CoS, which is what
#    lets us test whether the CONTRACT is complete/unambiguous (gaps surface as friction).
run_interview() {
  local d="$PRIV"
  note "interview Step 0 defaults the private repo to CWD + \`git init\`; the doc doesn't guard the case where CWD is already a populated/unrelated git repo (co-mingling risk for a newcomer who runs init in the wrong dir)."
  # Step 1 → identity.md
  { echo "# identity"
    echo "name: $PRIN_NAME"
    echo "address_as: $PRIN_ADDRESS"
    echo "timezone: $PRIN_TZ"
    echo "about: $PRIN_ONELINER"
  } > "$d/identity.md"
  # Step 2 → team.md (project roster) + priorities seed
  { echo "# team / roster"; echo; echo "## projects"
    IFS=';' read -ra REPOS <<< "$PRIN_REPOS"
    for r in "${REPOS[@]}"; do IFS='|' read -r n desc owner <<< "$r"; echo "- **$n** — $desc (owner: $owner)"; done
  } > "$d/team.md"
  # Step 4 → team.md AGAIN (people + agents) — same file, must MERGE not overwrite
  { echo; echo "## people"
    IFS=';' read -ra COLS <<< "$PRIN_COLLABORATORS"
    for x in "${COLS[@]}"; do IFS='|' read -r n f <<< "$x"; echo "- $n — $f"; done
    echo; echo "## agents"
    IFS=';' read -ra AGS <<< "$PRIN_AGENTS"
    for x in "${AGS[@]}"; do IFS='|' read -r n o <<< "$x"; echo "- $n — $o"; done
  } >> "$d/team.md"
  note "interview Steps 2 AND 4 both target team.md — a CoS must MERGE (append), not overwrite; the contract doesn't state the merge explicitly (a naive follower could clobber Step 2's roster)."
  # Step 3 → priorities.md
  { echo "# priorities"; echo
    IFS=';' read -ra PR <<< "$PRIN_PRIORITIES"; local i=1
    for p in "${PR[@]}"; do echo "$i. $p"; i=$((i+1)); done
  } > "$d/priorities.md"
  # Step 5 → sweeps: contract says "into priorities.md OR a sweeps.md" (ambiguous target)
  { echo "# sweeps"; echo "channels: $PRIN_CHANNELS"; echo "quiet_hours: $PRIN_QUIET"; } > "$d/sweeps.md"
  note "interview Step 5 says write the sweep config 'into priorities.md OR a sweeps.md' — an explicit ambiguity; a follower must pick, so two setups diverge on where watch-config lives. (Chose sweeps.md.)"
  # Step 6 → comms.md
  { echo "# comms (working agreement)"; echo "push: $PRIN_PUSH"; echo "style: $PRIN_STYLE"; echo "never_without_asking: $PRIN_NEVER"; } > "$d/comms.md"
  # consumed public contract is pinned + gitignored (real setup uses a submodule; we
  # record the pin + exclude the checkout so the private commit stays clean).
  echo "personas/" > "$d/.gitignore"
  # Finishing → commit (explicit files; distinct author; never -A, to skip the nested checkout)
  ( cd "$d" && git add identity.md team.md priorities.md comms.md sweeps.md personas.pin .gitignore \
    && git -c user.email='principal@eval.local' -c user.name="$PRIN_NAME" commit -q -m "first-run interview: initial CoS setup" )
}

rm -rf "$SANDBOX"; mkdir -p "$SANDBOX" "$STR"
printf 'real-path onboarding eval · CLI=%s · personas pin=%s\n' "$BIN" "${PERSONAS_PIN:0:12}"

# ── P0: consume the public personas, SHA-pinned, read-only ────────────────────
gate "P0 — consume public personas (SHA-pinned, read-only)"
mkdir -p "$PRIV"
( cd "$PRIV" && git init -q )                       # Step 0: cwd becomes the private cos repo
if git clone -q "$PERSONAS_URL" "$PRIV/personas" 2>/dev/null; then
  ( cd "$PRIV/personas" && git checkout -q "$PERSONAS_PIN" 2>/dev/null )
  GOT=$( cd "$PRIV/personas" && git rev-parse HEAD )
  echo "$PERSONAS_PIN" > "$PRIV/personas.pin"       # the reproducibility artifact
  [ "$GOT" = "$PERSONAS_PIN" ] && pass "personas pinned at ${PERSONAS_PIN:0:12} (reproducible)" || fail "personas not at pin (got ${GOT:0:12})"
  [ -r "$PRIV/personas/chief-of-staff.md" ] && pass "CoS role readable from the pinned personas (read-only consume)" || fail "chief-of-staff.md not readable"
else
  fail "could not clone $PERSONAS_URL — P0 needs network once (then fully offline). Skipping downstream."
  echo "VERDICT: BLOCKED (no network for P0)"; exit 1
fi

# ── P1: first-run detection (fresh → interview runs) ──────────────────────────
gate "P1 — first-run detection (fresh network → interview should run)"
# the contract's rule: 'populated' == identity.md exists AND names a principal.
first_run_needed() { ! grep -qiE '^(name|principal):[[:space:]]*[^[:space:]]' "$PRIV/identity.md" 2>/dev/null; }
if first_run_needed; then pass "no populated identity.md → interview triggers (correct)"; else fail "interview would wrongly SKIP on a fresh repo"; fi
note "'populated' is defined only loosely in the contract ('an identity.md with a set principal'). A stub identity.md (file present, principal blank) is an ambiguous middle state — the detection rule should be explicit about it."

# ── P2: run the interview (scripted principal) → private cos repo ──────────────
gate "P2 — first-run interview → private cos repo (scripted principal: $PRIN_NAME)"
run_interview
for f in identity.md team.md priorities.md comms.md; do
  [ -s "$PRIV/$f" ] && pass "wrote $f" || fail "missing $f"
done
grep -qi "$PRIN_NAME" "$PRIV/identity.md" && pass "identity.md names the principal ($PRIN_NAME)" || fail "principal not set in identity.md"
# team.md must contain BOTH the Step-2 roster AND the Step-4 people (merge, not clobber)
grep -qi "taskflow" "$PRIV/team.md" && grep -qi "Sam Ortiz" "$PRIV/team.md" && pass "team.md merged Step-2 roster + Step-4 people (no clobber)" || fail "team.md lost a section (merge failed)"
( cd "$PRIV" && git log --oneline 2>/dev/null | grep -qi 'first-run interview' ) && pass "committed 'first-run interview: initial CoS setup'" || fail "no first-run-interview commit"

# ── P3: NO-LEAK — the public/private split (the headline) ──────────────────────
gate "P3 — no-leak (public/private split)"
grep -rqi "$PRIN_NAME" "$PRIV"/*.md && pass "private cos repo carries the principal's data" || fail "private data missing from the private repo"
if grep -rqiE "$PRIN_NAME|taskflow|$PRIN_ADDRESS|Chicago" "$PRIV/personas" 2>/dev/null; then
  fail "LEAK: principal data found inside the consumed PUBLIC personas checkout"
else
  pass "public personas checkout has ZERO principal data (nothing leaked in)"
fi
DIRTY=$( cd "$PRIV/personas" && git status --porcelain )
[ -z "$DIRTY" ] && pass "personas checkout byte-for-byte unmodified at the pin (read-only consume held)" || fail "personas checkout was modified"

# ── P1b: idempotency — populated → interview SKIPS ────────────────────────────
gate "P1b — idempotency (populated repo → interview SKIPS, never re-runs)"
if first_run_needed; then fail "interview would RE-RUN over an existing setup (clobber risk)"; else pass "populated identity.md → interview correctly skips"; fi

# ── NET: the interviewed CoS joins the fresh network (ties to run.sh's A–D) ────
gate "NET — the interviewed CoS comes online in the network"
mkdir -p "$STR/cos/inbox" "$STR/cos/archive"
if c cos status cos --set available >/dev/null 2>&1 && c cos agents --json 2>/dev/null | grep -q '"cos"'; then
  pass "CoS available in the network (spawn + message end-to-end proven by run.sh)"
else
  fail "CoS did not come online after the interview"
fi

# ── summary ───────────────────────────────────────────────────────────────────
printf '\n─────────────────────────────────────────────\n'
[ "$GATE_FAIL" -eq 0 ] && printf 'VERDICT: PASS — the real onboarding chain works end-to-end (public personas consumed pinned → interview → private cos → network).\n' \
                        || printf 'VERDICT: FAIL — a gate failed (see ✗ above).\n'
printf 'FRICTION (interview + consumption contract): %d\n' "${#FRICTION[@]}"
i=1; for f in "${FRICTION[@]}"; do printf '  %d. %s\n' "$i" "$f"; i=$((i+1)); done
printf '─────────────────────────────────────────────\n'
exit "$GATE_FAIL"
