#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-ADD-STRUCTURE. Asserts the REAL `convoy add` + `convoy render` produced the
# redesign workspace overlay. Never a self-report — grades the on-disk shape probe.sh captured.
# Mutation-valid: a missing/wrong file FAILS; a self-test proves the presence check is real.
#
# STAGE SCOPE. convoy is declarative: add=declare, render=materialize, up=reconcile+launch. This cell covers
# add+render only — both deterministic, no model invoked, nothing spent. The bus folder belongs to `up` and is
# SKIPped here with its owning stage named rather than failed (see convoy-network for the `up` coverage).
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
if grep -q 'SEED-COMMIT-FAILED' "$P/shape.txt" 2>/dev/null; then
  no "the fixture's OWN seed commit failed — no baseline, so every gate below would misattribute the fixture's files to convoy"
  echo "SCORE: 0 PASS / 1 FAIL — fixture fault, NOT a convoy defect"; exit 1
fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }
echo "short-hostname this box: $(cat "$P/shorthost.txt" 2>/dev/null)"

echo
echo "== OVERLAY IN .convoy/ (hard gate) — the rig moved OUT of the repo root into .convoy/ =="
for f in PERSONA.md DING-BUS.md pty.toml; do
  g "convoy_has_$f=yes" && ok ".convoy/$f exists" || no ".convoy/$f MISSING after \`convoy add\` + \`convoy render\` — the probe now advances to the materialize stage, so this is a REAL gap (if render warned about smalltalk hooks, that is the cause: see render.out)"
done
g "has_settings=yes" && ok ".claude/settings.local.json exists (the hooks)" || no ".claude/settings.local.json MISSING"

echo
echo "== PRISTINE ROOT (hard gate) — all convoy files git-excluded => git status --porcelain EMPTY =="
if g "porcelain_empty=yes"; then ok "git status --porcelain is EMPTY — the product-repo root is pristine (no convoy pollution)"
else no "the repo is DIRTY after convoy add — convoy-authored files leaked into the working tree:"; sed 's/^/        /' "$P/porcelain.txt" 2>/dev/null; fi

echo
echo "== BUS FOLDER (stage-scoped) — <net>/smalltalk/<shorthost>.<identity>/ with inbox/ archive/ status =="
# STAGE. The bus folder is created by `convoy up` (reconcile+launch), not by `add` (declare) or
# `render` (materialize the overlay) — render reports "launched NO pty, touched NO bus". This cell is
# the DETERMINISTIC structural guard and deliberately stops before `up`, because `up` launches real
# agents and spends model budget. Grading a bus folder here would fail a correct system for not having
# done something it was never asked to do. Absence at this stage is EXPECTED, so it is a SKIP with the
# owning stage named — not a silent pass and not a FAIL. The bus-folder shape is owned by the cells
# that actually reach `up` (convoy-network, convoy-doctor-*).
if ! g "busdir=yes"; then
  sk "bus folder absent — created by \`convoy up\`, which this deterministic cell stops short of (see convoy-network)"
elif g "busdir=yes"; then
  ok "bus folder <net>/smalltalk/<host>.<identity>/ exists (smalltalk/ split + host-prefix)"
  g "host_parseable=yes" && ok "  host is parseable from the folder-name prefix (<host>.<identity>, doc 4aab4f1)" \
                         || no "  host NOT parseable from the bus-folder name (prefix missing)"
  # If a bus folder DOES exist here (a future convoy that materializes it earlier, or a reused net),
  # its shape is still worth grading. inbox/ + archive/ are structural; the `status` file is
  # RUNTIME/agent-created (the boot ritual runs `st status --set`; a missing one reads as offline).
  for s in inbox archive; do g "bus_has_$s=yes" && ok "  bus folder has $s" || no "  bus folder MISSING $s"; done
  g "bus_has_status=yes" && echo "  [info] status file present (an agent already set it)" \
                         || echo "  [info] no status file yet — RUNTIME/agent-created on boot (st status --set), NOT gated (a missing status reads as offline, per convoy-claude)"
fi

echo
echo "== NO --resume (hard gate) — pty.toml is a launch spec, not a conversation-resume =="
if g "pty_no_resume=yes"; then ok "pty.toml ($(sed -n 's/^pty_toml=//p' "$P/shape.txt")) carries NO --resume/--session-id"
elif g "pty_no_resume=no"; then no "pty.toml carries --resume/--session-id — it must be a cold-boot launch spec, no conversation id"
else sk "no pty.toml found to check for --resume"; fi

echo
echo "== LOADER (hard gate, doc 4aab4f1 SETTLED) — .claude/rules/convoy.md is the loader; NO root CLAUDE.local.md =="
g "has_loader=yes" && ok ".claude/rules/convoy.md exists — the loader (auto-loads + @-imports .convoy/, zero visible root file)" \
                   || no ".claude/rules/convoy.md MISSING after \`convoy add\` + \`convoy render\` — a REAL gap (check render.out for a smalltalk-hooks abort, which leaves the overlay partial)"
g "no_root_claude_local=yes" && ok "NO CLAUDE.local.md at the repo ROOT — the loader lives in .claude/rules/, so the root stays pristine" \
                             || no "a CLAUDE.local.md is at the repo ROOT — the redesign moved the loader to .claude/rules/convoy.md (no visible root file)"

echo
echo "== MUTATION-VALID (hard gate) — the presence checks are non-vacuous =="
g "selftest_bogus_absent=yes" && ok "a bogus .convoy/ file reads ABSENT — the presence checks genuinely test presence" \
                              || no "self-test failed — the presence checks may be vacuous"

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-add-structure: PASS — add+render produce the redesign overlay (.convoy/ rig, .claude/rules/ loader,"
  echo "    pristine root, no-resume pty.toml). Bus folder is out of scope at this stage (owned by \`convoy up\`)."
else
  echo "==> convoy-add-structure: FAIL — the add+render layout does not match the redesign target. Before blaming convoy,"
  echo "    check render.out: a smalltalk-hooks abort leaves the overlay PARTIAL and is a missing dependency, not a defect."
fi
[ "$fail" -eq 0 ]
