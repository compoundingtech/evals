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
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }
echo "short-hostname this box: $(cat "$P/shorthost.txt" 2>/dev/null)"

echo
echo "== OVERLAY IN .convoy/ (hard gate) — the rig moved OUT of the repo root into .convoy/ =="
for f in PERSONA.md DING-BUS.md pty.toml; do
  g "convoy_has_$f=yes" && ok ".convoy/$f exists" || no ".convoy/$f MISSING after \`convoy add\` — CHECK THE VERB SPLIT FIRST: current convoy is declarative (add=declare / render=materialize / up=reconcile), so \`convoy add\` alone writes NO overlay. Run \`convoy render <id>\` and re-check before concluding 'piece #1 not landed'"
done
g "has_settings=yes" && ok ".claude/settings.local.json exists (the hooks)" || no ".claude/settings.local.json MISSING"

echo
echo "== PRISTINE ROOT (hard gate) — all convoy files git-excluded => git status --porcelain EMPTY =="
if g "porcelain_empty=yes"; then ok "git status --porcelain is EMPTY — the product-repo root is pristine (no convoy pollution)"
else no "the repo is DIRTY after convoy add — convoy-authored files leaked into the working tree:"; sed 's/^/        /' "$P/porcelain.txt" 2>/dev/null; fi

echo
echo "== BUS FOLDER (hard gate) — <net>/smalltalk/<shorthost>.<identity>/ with inbox/ archive/ status =="
if g "busdir=yes"; then
  ok "bus folder <net>/smalltalk/<host>.<identity>/ exists (smalltalk/ split + host-prefix)"
  g "host_parseable=yes" && ok "  host is parseable from the folder-name prefix (<host>.<identity>, doc 4aab4f1)" \
                         || no "  host NOT parseable from the bus-folder name (prefix missing)"
  # inbox/ + archive/ are convoy-add-created (deterministic) => hard-gate. The `status` file is RUNTIME/agent-created
  # (the agent's boot ritual runs `st status --set`; a missing one reads as offline) => NOT a structure gate.
  for s in inbox archive; do g "bus_has_$s=yes" && ok "  bus folder has $s" || no "  bus folder MISSING $s"; done
  g "bus_has_status=yes" && echo "  [info] status file present (an agent already set it)" \
                         || echo "  [info] no status file yet — RUNTIME/agent-created on boot (st status --set), NOT gated (a missing status reads as offline, per convoy-claude)"
else
  no "bus folder <net>/smalltalk/<shorthost>.<identity>/ MISSING — smalltalk/ split + host-prefix not landed (current convoy = flat <net>/<identity>)"
fi

echo
echo "== NO --resume (hard gate) — pty.toml is a launch spec, not a conversation-resume =="
if g "pty_no_resume=yes"; then ok "pty.toml ($(sed -n 's/^pty_toml=//p' "$P/shape.txt")) carries NO --resume/--session-id"
elif g "pty_no_resume=no"; then no "pty.toml carries --resume/--session-id — it must be a cold-boot launch spec, no conversation id"
else sk "no pty.toml found to check for --resume"; fi

echo
echo "== LOADER (hard gate, doc 4aab4f1 SETTLED) — .claude/rules/convoy.md is the loader; NO root CLAUDE.local.md =="
g "has_loader=yes" && ok ".claude/rules/convoy.md exists — the loader (auto-loads + @-imports .convoy/, zero visible root file)" \
                   || no ".claude/rules/convoy.md MISSING — see the verb-split note above: \`convoy render\` materializes the overlay, \`convoy add\` no longer does"
g "no_root_claude_local=yes" && ok "NO CLAUDE.local.md at the repo ROOT — the loader lives in .claude/rules/, so the root stays pristine" \
                             || no "a CLAUDE.local.md is at the repo ROOT — the redesign moved the loader to .claude/rules/convoy.md (no visible root file)"

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
