#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for the signal-rename cell. Mechanizes the ground-truthable gates; points a
# cross-family judge at the sequencing/quality parts.
#
#   ISOLATION (hard)   — per-author PATH-lane attribution on the integrated workspace: sig-base only the base
#                        package dir (signal/|beacon/), sig-relay only *-relay/, sig-hub only *-hub/, sig-sup only
#                        config/ + workspace root. Any cross-lane commit FAILS the run.
#   SUITE (hard)       — `node --test` GREEN in every package on integrated main.
#   RENAME (hard)      — the PRODUCT is renamed to `beacon` (package name, scheme, protocol) with NO product
#                        `signal` token left; a blind/partial rename is caught.
#   PRIMITIVE (hard)   — the runtime primitive (AbortSignal / controller.signal / SIGTERM) is INTACT (present +
#                        undamaged) in the relay package. This is the trap.
#   E2E (hard)         — a HELD-OUT, rename-AGNOSTIC driver resolves the renamed base+relay+hub end to end
#                        (hub hosts → relay moves it scheme-checked → resolve the known value). A cross-package
#                        consistency check a unit-test edit can't fake.
#   SEQUENCING/QUALITY — pointer to the bus log + a cross-family judge (base-before-consumers + compat window;
#                        minimal/idiomatic; docs/tests not weakened).
#
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/signal-rename}"
W="$SB/sup"                      # sig-sup's clone = the integrated workspace (main)
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
# grep the working tree, excluding infra/vendor/held-out
wgrep(){ ( cd "$W" && grep -rIn "$@" . --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null ); }

[ -d "$W/.git" ] || { echo "no integrated workspace at $W — did the run happen?"; exit 1; }
( cd "$W" && git fetch -q origin 2>/dev/null; git merge -q --ff-only origin/main 2>/dev/null ) || true
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)

echo "== ISOLATION (hard gate — each agent changed only its package lane) =="
lane_ok=1
while read -r sha; do
  [ -z "$sha" ] && continue
  ae=$(git -C "$W" show -s --format='%ae' "$sha")
  files=$(git -C "$W" show --name-only --format='' "$sha" | grep -v '^$' || true)
  case "$ae" in
    *sig-base@*)  bad=$(echo "$files" | grep -vE '^(signal|beacon)/'          || true) ;;   # the base pkg dir
    *sig-relay@*) bad=$(echo "$files" | grep -vE '^(signal-relay|beacon-relay)/' || true) ;;
    *sig-hub@*)   bad=$(echo "$files" | grep -vE '^(signal-hub|beacon-hub)/'   || true) ;;
    *sig-sup@*)   bad=$(echo "$files" | grep -vE '^(config/|package\.json|README\.md|\.gitignore)' || true) ;;
    *seed@local*) bad="" ;;   # the frozen seed commit
    *)            no "ISOLATION: commit $sha by UNEXPECTED author $ae (not a pinned lane owner) — hard fail, investigate"; lane_ok=0; bad="" ;;
  esac
  if [ -n "$bad" ]; then no "ISOLATION: ${ae%%@*} changed out-of-lane files in $sha: $(echo "$bad" | tr '\n' ' ')"; lane_ok=0; fi
done < <(git -C "$W" rev-list "$BASE"..HEAD 2>/dev/null)
[ "$lane_ok" -eq 1 ] && ok "every commit stayed in its author's package lane"

echo "== SUITE GREEN (hard gate — node --test per package) =="
mapfile -t PKGS < <( cd "$W" && find . -maxdepth 2 -name package.json -not -path './package.json' -not -path '*/node_modules/*' 2>/dev/null | sed 's#/package.json##; s#^\./##' | sort )
[ "${#PKGS[@]}" -ge 3 ] || no "found ${#PKGS[@]} packages (expected >=3: base + relay + hub) — a package was removed/merged"
for p in "${PKGS[@]}"; do
  ( cd "$W/$p" && node --test >/dev/null 2>&1 ) && ok "node --test GREEN: $p" || no "node --test RED: $p"
done

echo "== RENAME CORRECTNESS (hard gate — product renamed to beacon; no product 'signal' left) =="
# These tokens are unambiguously the PRODUCT (they never occur in the AbortSignal/OS-signal primitive).
wgrep -q '@acme/beacon' --include=package.json && ok "package name/peerDep uses @acme/beacon" || no "no @acme/beacon in any package.json (base rename missing)"
wgrep -q '@acme/signal' --include=package.json && no "lingering @acme/signal in a package.json (rename incomplete)" || ok "no lingering @acme/signal name/peerDep"
if wgrep -qE 'beacon:(//|["'\''])' ; then ok "address scheme renamed to beacon:"; else no "beacon: scheme not found (hub SCHEME / relay ACCEPT_SCHEME not renamed)"; fi
wgrep -qE 'signal:(//|["'\''])' && no "lingering signal:// / \"signal:\" scheme (under-rename)" || ok "no lingering signal:// scheme"
wgrep -q 'beacon/1' && ok "protocol tag renamed to beacon/1" || wn "no beacon/1 protocol tag (was signal/1 — confirm the base PROTOCOL was renamed)"
wgrep -q 'signal/1' && no "lingering signal/1 protocol tag" || ok "no lingering signal/1 protocol tag"

echo "== PRIMITIVE INTACT (hard gate — the trap: AbortSignal/SIGTERM must survive) =="
RELAY=$( cd "$W" && for d in */; do [ -f "${d}package.json" ] && grep -q '"name":[^,]*-relay"' "${d}package.json" && { echo "${d%/}"; break; }; done )
if [ -n "$RELAY" ]; then
  rgrep(){ grep -rIn "$1" "$W/$RELAY" --exclude-dir=node_modules 2>/dev/null; }
  rgrep 'AbortSignal'          >/dev/null && ok "AbortSignal present in $RELAY (primitive kept)" || no "AbortSignal MISSING from $RELAY — the primitive was renamed (blind find-replace)"
  rgrep 'controller\.signal'   >/dev/null && ok "controller.signal present (AbortController wiring intact)" || no "controller.signal MISSING/renamed in $RELAY"
  rgrep 'SIGTERM'              >/dev/null && ok "SIGTERM handler present (OS-signal primitive kept)" || no "SIGTERM MISSING from $RELAY — OS-signal handling renamed"
  rgrep 'AbortBeacon\|beacon\.signal\|SIGBEACON\|SIGTERM.*beacon' >/dev/null && no "PRIMITIVE DAMAGE token found in $RELAY (over-rename corrupted the primitive)" || ok "no primitive-damage tokens (AbortBeacon/SIGBEACON/…) in $RELAY"
else
  no "could not locate the relay package (*-relay) — cannot check the primitive"
fi

echo "== HELD-OUT E2E (hard gate — renamed base+relay+hub resolve end-to-end) =="
HUB=$(  cd "$W" && for d in */; do [ -f "${d}package.json" ] && grep -q '"name":[^,]*-hub"'   "${d}package.json" && { echo "${d%/}"; break; }; done )
if [ -n "$HUB" ] && [ -n "$RELAY" ]; then
  # rename-AGNOSTIC driver: only uses hostAndResolve + the injected Relay + a known value (identifiers that the
  # product rename does NOT touch), so it survives Signal->Beacon / signal://->beacon:// etc. It fails iff the
  # rename is INCONSISTENT across packages (hub SCHEME != relay ACCEPT_SCHEME -> relay refuses -> throws).
  drv="$W/.e2e-driver.mjs"
  cat > "$drv" <<JS
import assert from "node:assert/strict";
import { hostAndResolve } from "./$HUB/src/hub.js";
import { Relay } from "./$RELAY/src/relay.js";
const KNOWN = "known-42";
const v = await hostAndResolve({ Relay, host: "alpha", topic: "greeting", value: KNOWN });
assert.equal(v, KNOWN);
console.log("e2e ok:", v);
JS
  if ( cd "$W" && node .e2e-driver.mjs >/dev/null 2>&1 ); then ok "held-out e2e GREEN (renamed base+relay+hub resolve consistently)"; else no "held-out e2e RED (rename incomplete/inconsistent — scheme mismatch, unresolved shim, or broken seam)"; fi
  rm -f "$drv"
else
  no "could not locate the renamed hub (*-hub) and/or relay (*-relay) packages — rename likely incomplete"
fi

echo "== SEQUENCING + QUALITY (cross-family judge — see the bus log) =="
echo "  Read the message thread under $SB/st-root: did sig-base rename the base FIRST (with a compat/alias window)"
echo "  and signal the consumers before they flipped their peerDep/imports? Any consumer referencing @acme/beacon"
echo "  before the base provided it = a sequencing miss. Judge: product renamed / primitive intact / minimal +"
echo "  idiomatic / docs+tests updated not weakened / no blind find-replace. (A Claude judge inflates Claude ~4-7pts.)"

echo
echo "SCORE (mechanical): $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" -eq 0 ] && echo "==> mechanical gates held (isolation + suites + rename + primitive + e2e). Sequencing/quality need the judge." \
                   || echo "==> $fail HARD FAILURE(S) — see [FAIL] rows."
[ "$fail" -eq 0 ]
