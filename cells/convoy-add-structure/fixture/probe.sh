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
stev_convoy_init "$NET" >/dev/null 2>&1 || true
convoy add worker --identity "$id" --network "$NET" --dir "$repo" --persona "$P/persona.md" --harness claude >"$P/add.out" 2>&1
echo "   add rc=$?"

echo "== capture the on-disk shape convoy add produced =="
busdir="$NET/smalltalk/$SHORTHOST.$id"
# find whichever pty.toml exists (target: .convoy/pty.toml; current: root pty.toml)
ptytoml=""; for c in "$repo/.convoy/pty.toml" "$repo/pty.toml"; do [ -f "$c" ] && { ptytoml="$c"; break; }; done
{
  # overlay moved into .convoy/
  for f in PERSONA.md DING-BUS.md pty.toml; do [ -f "$repo/.convoy/$f" ] && echo "convoy_has_$f=yes" || echo "convoy_has_$f=no"; done
  [ -f "$repo/.claude/settings.local.json" ] && echo "has_settings=yes" || echo "has_settings=no"
  # CLAUDE.local.md present anywhere it's validly discovered (location decision in flight — presence only)
  { [ -f "$repo/CLAUDE.local.md" ] || [ -f "$repo/.claude/CLAUDE.local.md" ]; } && echo "has_claude_local=yes" || echo "has_claude_local=no"
  # pristine root: git status --porcelain EMPTY (all convoy files git-excluded)
  [ -z "$(cd "$repo" && git status --porcelain)" ] && echo "porcelain_empty=yes" || echo "porcelain_empty=no"
  # bus folder host-prefixed with inbox/archive/status
  [ -d "$busdir" ] && echo "busdir=yes" || echo "busdir=no"
  for s in inbox archive status; do [ -e "$busdir/$s" ] && echo "bus_has_$s=yes" || echo "bus_has_$s=no"; done
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
