#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-doctor-foreign-box) — DETERMINISTIC, box-free (--quick), no LLM. Guards the two Johannes
# doctor FALSE-NEGATIVES (convoy #77 auth-probe classifier + #78 st-hooks discovery): on a FOREIGN box —
# `st` OFF PATH + an INCONCLUSIVE claude auth probe — `convoy doctor` must report HONESTLY, never say untrue
# things. It captures doctor's REAL output for two runs of the SAME foreign box:
#   fb.out  — INCONCLUSIVE claude probe (a non-auth error): honest = "could not verify Claude auth", NOT a
#             false "Claude is NOT signed in"; and st-off-PATH must NOT yield a false "hooks NOT found".
#   out.out — CONTRAST: a CLEAR not-logged-in claude probe → doctor DOES say "NOT signed in" (mutation-valid:
#             proves the auth check is non-vacuous — it can and does report signed-out on a real signal).
#
# Foreign box = a box that isn't the one that set the network up (Johannes): `st` is not on PATH, but the
# hooks are wired via each agent's absolute ST_BIN. We build it by removing every st-carrying dir from PATH
# (re-providing node/pty so convoy still runs) and pointing ST_BIN at the real st; the claude probe is driven
# by a shim so its outcome is deterministic (no live auth needed).
#
# ISOLATION: env -u ST_ROOT/PTY_ROOT/CONVOY_NETWORK + --network <sandbox> (a bare doctor / ST_ROOT hits the
# operator's REAL default net); --quick spawns no agents. Never touches the live fleet.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdfb}"   # SHORT path (keeps PTY_ROOT under the doctor's length gate)
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"
cv(){ env -u ST_ROOT -u PTY_ROOT -u CONVOY_NETWORK convoy "$@"; }

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'PROBE-SKIP\n' > "$P/shape.txt"; exit 0
fi
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (ahead of committed sha)"
} > "$P/convoy-version.txt" 2>/dev/null || true

# st must be installed to build the foreign box (st off PATH but hooks wired via its absolute ST_BIN).
st_real="$(command -v st 2>/dev/null || true)"
if [ -z "$st_real" ]; then
  echo "SKIP: st not installed — cannot construct the st-off-PATH foreign box" >&2
  printf 'PROBE-SKIP\n' > "$P/shape.txt"; exit 0
fi
ST_BIN_REAL="$(readlink -f "$st_real" 2>/dev/null || realpath "$st_real" 2>/dev/null || echo "$st_real")"

# --- FOREIGN-BOX PATH: drop EVERY dir that carries an `st`, re-provide node/pty/convoy so convoy still runs ---
FB="$SB/fb-bin"; mkdir -p "$FB"        # holds node/pty/convoy — deliberately NO st
stdir="$(cd "$(dirname "$st_real")" && pwd)"
for t in node pty; do [ -x "$stdir/$t" ] && ln -sf "$stdir/$t" "$FB/$t"; done
ln -sf "$(command -v convoy)" "$FB/convoy" 2>/dev/null || true
PATH_NOST="$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r d; do
  [ -n "$d" ] || continue; [ -x "$d/st" ] && continue; printf '%s\n' "$d"; done | paste -sd: -)"
FBPATH="$FB:$PATH_NOST"                 # st is unreachable here; node/pty/convoy + all non-st system dirs remain

# --- claude shims (named `claude`, resolved before the now-off-PATH real one) ---
INC="$SB/claude-inconclusive"; mkdir -p "$INC"   # a NON-auth error (sandbox denial); no AUTH_FAIL words; exit 1
cat > "$INC/claude" <<'SHIM'
#!/usr/bin/env bash
echo "sandbox: operation not permitted (seatbelt denied a file op)" >&2
exit 1
SHIM
chmod +x "$INC/claude"
SGO="$SB/claude-signout"; mkdir -p "$SGO"        # a CLEAR not-logged-in signal (the mutation-valid contrast)
cat > "$SGO/claude" <<'SHIM'
#!/usr/bin/env bash
echo "Not logged in · Please run /login"
exit 0
SHIM
chmod +x "$SGO/claude"

# --- isolated net (short path) ---
mega="$SB/mega"; mkdir -p "$mega"; git -C "$mega" init -q
git -C "$mega" config user.email m@e.l; git -C "$mega" config user.name m
printf '# m\n' > "$mega/README.md"; git -C "$mega" add -A && git -C "$mega" commit -q -m seed
cv init "$SB/net" --megarepo "$mega" --quiet >/dev/null 2>&1

echo "== FOREIGN BOX: st OFF PATH (+ ST_BIN) + an INCONCLUSIVE claude probe =="
PATH="$INC:$FBPATH" ST_BIN="$ST_BIN_REAL" cv doctor --quick --network "$SB/net" > "$P/fb.out" 2>&1; echo "$?" > "$P/fb.rc"
echo "== CONTRAST: same foreign box, but a CLEAR not-logged-in claude probe (mutation-valid) =="
PATH="$SGO:$FBPATH" ST_BIN="$ST_BIN_REAL" cv doctor --quick --network "$SB/net" > "$P/out.out" 2>&1; echo "$?" > "$P/out.rc"

echo "== capture the shape (grep doctor's REAL output — never a self-report) =="
{
  # the foreign-box condition is REAL: st genuinely off PATH in the run (Tooling flags it)
  grep -qiE 'st +NOT on PATH|st .*not on PATH' "$P/fb.out" && echo "fb_st_offpath=yes" || echo "fb_st_offpath=no"
  # #78 HOOKS honesty — st off PATH must NOT yield a false "hooks NOT found"
  grep -qiE 'hooks found' "$P/fb.out"                       && echo "fb_hooks_found=yes"     || echo "fb_hooks_found=no"
  grep -qiE 'hooks NOT found|smalltalk hooks NOT'           "$P/fb.out" && echo "fb_hooks_notfound=yes" || echo "fb_hooks_notfound=no"
  # #77 AUTH honesty — an inconclusive probe is "could not verify", NOT a false "NOT signed in"
  grep -qiE 'could not verify Claude auth|probe errored'    "$P/fb.out" && echo "fb_auth_inconclusive=yes" || echo "fb_auth_inconclusive=no"
  grep -qiE 'Claude is NOT signed in'                       "$P/fb.out" && echo "fb_auth_signedout=yes"    || echo "fb_auth_signedout=no"
  # CONTRAST — a CLEAR signal DOES yield "NOT signed in" (the auth check is non-vacuous)
  grep -qiE 'Claude is NOT signed in'                       "$P/out.out" && echo "ct_auth_signedout=yes"    || echo "ct_auth_signedout=no"
} > "$P/shape.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== teardown =="; cv down "$SB/net" --force >/dev/null 2>&1 || true
echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
