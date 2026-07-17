#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-add-structure) — DETERMINISTIC, box-free, no LLM. Runs the REAL `convoy add` into a repo on an
# isolated net and captures the on-disk shape grade.sh asserts against the redesign target
# (cos notes/convoy-structure-redesign.md):
#   • workspace overlay moved into .convoy/: PERSONA.md + DING-BUS.md + pty.toml
#   • .claude/settings.local.json (the hooks)
#   • CLAUDE.local.md present + git-excluded (EXACT location root-vs-.claude is IN FLIGHT — held, not asserted here)
#   • ALL git-excluded => `git status --porcelain` EMPTY (pristine product-repo root)
#   • bus folder <net>/smalltalk/<shorthost>.<identity>/ with inbox/ + archive/ + status
#   • pty.toml carries NO --resume
#
# RED now / GREEN as the redesign lands: today's convoy writes the rig into the repo ROOT + a flat <net>/<id> bus
# folder, so this cell is RED until pieces #1 (.convoy/ overlay) + #3 (smalltalk/ + host-prefix) land.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cas}"
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
repo="$SB/repo"; NET="$SB/net"; id="asw"
SHORTHOST="$(hostname 2>/dev/null | cut -d. -f1 | tr 'A-Z' 'a-z')"; [ -n "$SHORTHOST" ] || SHORTHOST="localhost"
printf '%s\n' "$SHORTHOST" > "$P/shorthost.txt"

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/shape.txt"; exit 0
fi

mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" config user.name  "as-agent"; git -C "$repo" config user.email "as-agent@eval.local"
printf '# convoy-add-structure test repo\n' > "$repo/CLAUDE.md"
git -C "$repo" add -A && git -C "$repo" commit -q -m "seed"
printf '# add-structure worker %s\nYou are %s.\n' "$id" "$id" > "$P/persona.md"
export ST_ROOT="$NET"; export PTY_ROOT="$NET/pty"
trap 'stev_convoy_teardown "$NET" >/dev/null 2>&1 || true' EXIT INT TERM

echo "== convoy init the isolated net, then run the REAL convoy add into the repo =="
# Record WHICH convoy this ran against (the layout is convoy-version-dependent; the redesign lands incrementally).
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (may be ahead of the committed SHA — redesign piece in progress)"
} > "$P/convoy-version.txt" 2>/dev/null || true
stev_convoy_init "$NET" >/dev/null 2>&1 || true
convoy add worker --identity "$id" --network "$NET" --dir "$repo" --persona "$P/persona.md" --harness claude >"$P/add.out" 2>&1
echo "   add rc=$?"

echo "== capture the on-disk shape convoy add produced =="
# Bus folder: find <net>/smalltalk/<host>.<identity>/ by GLOB (host = the name PREFIX, doc 4aab4f1 — no separate
# host file). Portable: we don't derive the hostname ourselves; we parse it from the folder convoy created.
busdir="$(ls -d "$NET"/smalltalk/*."$id" 2>/dev/null | head -1)"
host_prefix=""; [ -n "$busdir" ] && host_prefix="$(basename "$busdir" | sed "s/\\.$id\$//")"
# find whichever pty.toml exists (target: .convoy/pty.toml; current: root pty.toml)
ptytoml=""; for c in "$repo/.convoy/pty.toml" "$repo/pty.toml"; do [ -f "$c" ] && { ptytoml="$c"; break; }; done
{
  # overlay moved into .convoy/
  for f in PERSONA.md DING-BUS.md pty.toml; do [ -f "$repo/.convoy/$f" ] && echo "convoy_has_$f=yes" || echo "convoy_has_$f=no"; done
  [ -f "$repo/.claude/settings.local.json" ] && echo "has_settings=yes" || echo "has_settings=no"
  # LOADER (doc 4aab4f1 SETTLED): .claude/rules/convoy.md is the loader (auto-loads + @-imports .convoy/); NOT root CLAUDE.local.md.
  [ -f "$repo/.claude/rules/convoy.md" ] && echo "has_loader=yes" || echo "has_loader=no"
  [ -f "$repo/CLAUDE.local.md" ] && echo "no_root_claude_local=no" || echo "no_root_claude_local=yes"
  # pristine root: git status --porcelain EMPTY (all convoy files git-excluded => zero visible root file)
  [ -z "$(cd "$repo" && git status --porcelain)" ] && echo "porcelain_empty=yes" || echo "porcelain_empty=no"
  # bus folder <net>/smalltalk/<host>.<identity>/ (host parseable from the name prefix) with inbox/archive/status
  { [ -n "$busdir" ] && [ -d "$busdir" ]; } && echo "busdir=yes" || echo "busdir=no"
  [ -n "$host_prefix" ] && echo "host_parseable=yes ($host_prefix)" || echo "host_parseable=no"
  for s in inbox archive status; do { [ -n "$busdir" ] && [ -e "$busdir/$s" ]; } && echo "bus_has_$s=yes" || echo "bus_has_$s=no"; done
  # pty.toml carries NO --resume
  if [ -n "$ptytoml" ]; then grep -qiE -- '--resume|--session-id' "$ptytoml" && echo "pty_no_resume=no" || echo "pty_no_resume=yes"; echo "pty_toml=$ptytoml"; else echo "pty_no_resume=unknown"; echo "pty_toml=none"; fi
  # SELF-TEST (mutation-validity): a bogus overlay file must read absent (presence check non-vacuous)
  [ -f "$repo/.convoy/__nope__" ] && echo "selftest_bogus_absent=no" || echo "selftest_bogus_absent=yes"
} > "$P/shape.txt"
# what leaked into porcelain (RED context)
( cd "$repo" && git status --porcelain ) > "$P/porcelain.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
