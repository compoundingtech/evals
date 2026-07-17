#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-init-structure) — DETERMINISTIC, box-free, no LLM. Runs the REAL `convoy init <net>` in an
# isolated short path and captures the on-disk shape grade.sh asserts against the redesign target
# (cos notes/convoy-structure-redesign.md): a named network directory containing smalltalk/ + pty/ + worktrees/,
# with the network config recorded.
#
# RED now / GREEN as the redesign lands: today's convoy makes a FLAT net (no smalltalk/pty/worktrees subdirs), so
# this cell is RED until the named-net + smalltalk/pty/worktrees pieces land — the durable regression guard.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cis}"
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
NET="$SB/net"

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/init.out"; exit 0
fi

echo "== run the REAL convoy init <net> (isolated) =="
# Record WHICH convoy this ran against (the layout is convoy-version-dependent; the redesign lands incrementally).
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (may be ahead of the committed SHA — redesign piece in progress)"
} > "$P/convoy-version.txt" 2>/dev/null || true
convoy init "$NET" > "$P/init.out" 2>&1; echo "   init rc=$? (path used as-is => $NET)"

# NAMED NETWORKS (#2): a bare NAME resolves under <state-home>/convoy/<name>/. Isolate via a redirected state home
# (XDG_STATE_HOME) so we never touch the operator's real ~/.local/state/convoy. (A bare `convoy init` with no arg
# hits the real state home and is NOT isolatable — so we test the bare-NAME form, which is.)
XDG="$SB/xdg"; mkdir -p "$XDG"
XDG_STATE_HOME="$XDG" convoy init nettest >> "$P/init.out" 2>&1
NAMED="$XDG/convoy/nettest"

echo "== capture the on-disk shape convoy init produced =="
# Full tree (2 levels) for the human + the grader's context.
( cd "$NET" 2>/dev/null && find . -maxdepth 2 | sort ) > "$P/tree.txt" 2>/dev/null
# Presence of each REQUIRED redesign subdir.
{
  for d in smalltalk pty worktrees; do
    [ -d "$NET/$d" ] && echo "has_$d=yes" || echo "has_$d=no"
  done
  # NAMED NETWORKS (#2): a bare name -> <state-home>/convoy/<name>/ ; a path -> used as-is.
  [ -d "$NAMED" ] && echo "named_net=yes" || echo "named_net=no"
  [ -d "$NET" ] && echo "path_as_is=yes" || echo "path_as_is=no"
  # config recorded: some network-config artifact exists (exact filename TBD w/ convoy-claude — accept a few).
  cfg=""; for f in convoy.toml config.toml network.toml convoy.json .convoy.toml; do [ -f "$NET/$f" ] && cfg="$f"; done
  [ -n "$cfg" ] && echo "config_recorded=$cfg" || echo "config_recorded=no"
  # SELF-TEST (mutation-validity): a bogus subdir MUST read absent, proving the presence check is real (non-vacuous).
  [ -d "$NET/__definitely_not_a_real_subdir__" ] && echo "selftest_bogus_absent=no" || echo "selftest_bogus_absent=yes"
} > "$P/shape.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== teardown the isolated nets =="
stev_convoy_teardown "$NET" >/dev/null 2>&1 || true
stev_convoy_teardown "$NAMED" >/dev/null 2>&1 || true

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
