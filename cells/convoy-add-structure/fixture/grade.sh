#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-ADD-STRUCTURE. Asserts the REAL `convoy add` produced the redesign workspace
# overlay + bus folder (cos notes/convoy-structure-redesign.md). Never a self-report — grades the on-disk shape
# probe.sh captured. Mutation-valid: a missing/wrong folder FAILS; a self-test proves the presence check is real.
#
# Expect RED until pieces #1 (.convoy/ overlay) + #3 (smalltalk/ + host-prefix bus folders) land; GREEN after.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cas}"
P="$SB/.probe"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
g(){ grep -q "^$1" "$P/shape.txt"; }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'CONVOY-MISSING' "$P/shape.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi
echo "short-hostname this box: $(cat "$P/shorthost.txt" 2>/dev/null)"

echo
echo "== OVERLAY IN .convoy/ (hard gate) — the rig moved OUT of the repo root into .convoy/ =="
for f in PERSONA.md DING-BUS.md pty.toml; do
  g "convoy_has_$f=yes" && ok ".convoy/$f exists" || no ".convoy/$f MISSING — the rig is not under .convoy/ (piece #1 not landed / regressed)"
done
g "has_settings=yes" && ok ".claude/settings.local.json exists (the hooks)" || no ".claude/settings.local.json MISSING"

echo
echo "== PRISTINE ROOT (hard gate) — all convoy files git-excluded => git status --porcelain EMPTY =="
if g "porcelain_empty=yes"; then ok "git status --porcelain is EMPTY — the product-repo root is pristine (no convoy pollution)"
else no "the repo is DIRTY after convoy add — convoy-authored files leaked into the working tree:"; sed 's/^/        /' "$P/porcelain.txt" 2>/dev/null; fi

echo
echo "== BUS FOLDER (hard gate) — <net>/smalltalk/<shorthost>.<identity>/ with inbox/ archive/ status =="
if g "busdir=yes"; then
  ok "bus folder <net>/smalltalk/<shorthost>.<identity>/ exists (smalltalk/ split + host-prefix)"
  for s in inbox archive status; do g "bus_has_$s=yes" && ok "  bus folder has $s" || no "  bus folder MISSING $s"; done
else
  no "bus folder <net>/smalltalk/<shorthost>.<identity>/ MISSING — smalltalk/ split + host-prefix not landed (current convoy = flat <net>/<identity>)"
fi

echo
echo "== NO --resume (hard gate) — pty.toml is a launch spec, not a conversation-resume =="
if g "pty_no_resume=yes"; then ok "pty.toml ($(sed -n 's/^pty_toml=//p' "$P/shape.txt")) carries NO --resume/--session-id"
elif g "pty_no_resume=no"; then no "pty.toml carries --resume/--session-id — it must be a cold-boot launch spec, no conversation id"
else sk "no pty.toml found to check for --resume"; fi

echo
echo "== CLAUDE.local.md (soft — exact location root-vs-.claude IN FLIGHT, pending convoy-claude) =="
g "has_claude_local=yes" && wn "CLAUDE.local.md present + (porcelain-empty implies) git-excluded — location assertion HELD until convoy-claude confirms root vs .claude/" \
                         || wn "no CLAUDE.local.md found (root or .claude/) — the persona-overlay loader is absent (or piece not landed); location decision pending"

echo
echo "== MUTATION-VALID (hard gate) — the presence checks are non-vacuous =="
g "selftest_bogus_absent=yes" && ok "a bogus .convoy/ file reads ABSENT — the presence checks genuinely test presence" \
                              || no "self-test failed — the presence checks may be vacuous"

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-add-structure: PASS — convoy add produces the redesign overlay (.convoy/ rig, pristine root, host-prefixed"
  echo "    smalltalk/ bus folder, no-resume pty.toml). (CLAUDE.local.md exact location still pending convoy-claude.)"
else
  echo "==> convoy-add-structure: FAIL — the add layout does not match the redesign target. Expected RED until pieces #1"
  echo "    (.convoy/ overlay) + #3 (smalltalk/ + host-prefix) land; this cell is the regression guard for that structure."
fi
[ "$fail" -eq 0 ]
