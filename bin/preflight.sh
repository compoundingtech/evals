#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# evals preflight — detect what's installed, report which cells you can run.
#
# The preflight rule: detect what a person has installed and that determines
# which cells they can run. A cell runs only if EVERY capability it needs is
# present. Cross-family JUDGING (a quality judge from a different family than the
# subject under test) needs >=2 model families installed — reported separately.
#
#   preflight.sh            # human table
#   preflight.sh --runnable # just the runnable cell names (one per line; for scripting)
#   preflight.sh --json     # machine-readable
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${EVALS_MANIFEST:-$HERE/../cells.manifest}"
MODE="${1:-table}"

# whitespace trim that (unlike xargs) is safe on apostrophes/quotes in the manifest
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# ── capability detection ──────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }
have_st()   { have st || have smalltalk; }
have_glm()  { have ollama && ollama list 2>/dev/null | grep -qiE 'glm'; }

declare -A CAP
CAP[claude]=$( have claude   && echo 1 || echo 0 )
CAP[codex]=$(  have codex    && echo 1 || echo 0 )
CAP[glm]=$(    have_glm      && echo 1 || echo 0 )
CAP[st]=$(     have_st       && echo 1 || echo 0 )
CAP[pty]=$(    have pty      && echo 1 || echo 0 )
CAP[convoy]=$( have convoy   && echo 1 || echo 0 )
CAP[git]=$(    have git      && echo 1 || echo 0 )
CAP[node]=$(   have node     && echo 1 || echo 0 )
CAP[gh]=$(     have gh       && echo 1 || echo 0 )
CAP[network]=1   # assume present; individual cells that need it fail loudly if not

FAMILIES=$(( CAP[claude] + CAP[codex] + CAP[glm] ))
CROSS_FAMILY=$(( FAMILIES >= 2 ? 1 : 0 ))

# ── evaluate each cell against its caps ───────────────────────────────────────
runnable=(); skipped=()
while IFS='|' read -r cell type ship caps disc; do
  cell="$(trim "$cell")"; [ -z "$cell" ] && continue
  case "$cell" in \#*) continue;; esac
  caps="$(trim "$caps")"
  missing=""
  IFS=',' read -ra need <<< "$caps"
  for cap in "${need[@]}"; do
    cap="$(trim "$cap")"
    [ "${CAP[$cap]:-0}" = "1" ] || missing="$missing $cap"
  done
  if [ -z "$missing" ]; then runnable+=("$cell"); else skipped+=("$cell:$missing"); fi
done < "$MANIFEST"

# ── output ────────────────────────────────────────────────────────────────────
case "$MODE" in
  --runnable) printf '%s\n' "${runnable[@]}";;
  --json)
    printf '{"tools":{'; first=1
    for k in claude codex glm st pty convoy git node gh; do [ $first = 1 ] || printf ','; first=0; printf '"%s":%s' "$k" "${CAP[$k]}"; done
    printf '},"families":%s,"cross_family_judging":%s,"runnable":[' "$FAMILIES" "$CROSS_FAMILY"
    first=1; for c in "${runnable[@]}"; do [ $first = 1 ] || printf ','; first=0; printf '"%s"' "$c"; done
    printf '],"skipped":['; first=1
    for s in "${skipped[@]}"; do [ $first = 1 ] || printf ','; first=0; printf '"%s"' "${s%%:*}"; done
    printf ']}\n';;
  *)
    echo "evals preflight — installed capabilities"
    for k in claude codex glm st pty convoy git node gh; do
      printf '  %-7s %s\n' "$k" "$( [ "${CAP[$k]}" = 1 ] && echo '✓' || echo '—' )"
    done
    echo "  families present: $FAMILIES  ·  cross-family judging: $( [ $CROSS_FAMILY = 1 ] && echo 'available (>=2 families)' || echo 'unavailable (need >=2 families)' )"
    echo
    echo "RUNNABLE cells (${#runnable[@]}):"
    for c in "${runnable[@]}"; do printf '  ✓ %s\n' "$c"; done
    if [ "${#skipped[@]}" -gt 0 ]; then
      echo; echo "SKIPPED (missing capability):"
      for s in "${skipped[@]}"; do printf '  — %-22s needs:%s\n' "${s%%:*}" "${s#*:}"; done
    fi;;
esac
