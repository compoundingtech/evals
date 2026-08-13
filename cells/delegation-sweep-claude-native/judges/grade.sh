#!/usr/bin/env bash
# JUDGE (held out): the title call-site audit. Identical bytes in every arm of this task; the KDL passes the
# arm in, so the outcome oracle can never differ between arms.
#
#   grade.sh outcome            the coordinator summary names exactly the modules that reach legacyTitle()
#   grade.sh slices             both slice deliverables exist, are attributed, distinct, and each correct
#   grade.sh isolation          the audited repository is byte-identical to the frozen baseline
#   grade.sh delegation <arm>   the arm's delegation evidence (bus peers for st2, native log for native)
#
# PASS = exit 0. Every mode prints its reasoning; judge stdout is only visible when a human runs the script.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
SPEC="${SPEC_DIR:-$PWD}"
BUS="${ST_ROOT:-$ROOT}"
F="$ROOT/findings"
MODE="${1:-outcome}"
ARM="${2:-}"

# Held-out ground truth: files under repo/src and repo/scripts whose execution reaches legacyTitle().
# src/compat/index.js only re-exports, src/render/preview.js names it in a comment, src/audit/report.js in a
# string, test/ and docs/ are out of scope — none of those count.
SLICE1_TRUTH="src/export/markdown.js
src/render/card.js
src/render/list.js"
SLICE2_TRUTH="scripts/backfill-titles.js
src/compat/title-helpers.js
src/search/index-entry.js"

items() { # items <file> <lowercased-heading-substring>
  [ -f "$1" ] || return 0
  awk -v want="$2" '
    /^[[:space:]]*#{2,4}[[:space:]]/ { inside = (index(tolower($0), want) > 0); next }
    inside && /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+/, "", line)
      print line
    }
  ' "$1"
}

norm() { # normalize list items to repo-relative source paths, one per line, sorted and deduplicated
  tr -d '`*_"'"'"',' |
    awk '{ print $1 }' |
    sed -e 's#^\./##' -e 's#^/##' -e 's#^repo/##' |
    grep -E '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*\.(js|mjs|cjs|json|md)$' |
    LC_ALL=C sort -u
}

compare_set() { # compare_set <label> <expected> <actual>
  local label="$1" expected="$2" actual="$3" missing extra
  missing="$(LC_ALL=C comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | tr '\n' ' ')"
  extra="$(LC_ALL=C comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | tr '\n' ' ')"
  if [ -n "$missing" ] || [ -n "$extra" ]; then
    echo "FAIL: $label is wrong"
    [ -z "$missing" ] || echo "  missing: $missing"
    [ -z "$extra" ] || echo "  wrongly listed: $extra"
    return 1
  fi
  echo "PASS: $label lists exactly the modules that reach legacyTitle()"
}

attributed() { # attributed <file> -> prints the delegate label
  awk '
    /^[[:space:]]*delegate:[[:space:]]*[^[:space:]]/ {
      sub(/^[[:space:]]*delegate:[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      print
      exit
    }
  ' "$1"
}

busdir() { # tolerate the host/team prefix on a bus id
  local id="$1" d
  d="$(ls -d "$BUS"/*."$id" "$BUS/$id" 2>/dev/null | head -1)"
  printf '%s\n' "${d:-$BUS/$id}"
}

messages_from() { # messages_from <owner-suffix> <sender-suffix>
  local owner from
  owner="$(busdir "$1")"
  from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" \
    "$owner/inbox" "$owner/archive" 2>/dev/null
}

fail=0

case "$MODE" in
outcome)
  [ -f "$F/summary.md" ] || { echo "FAIL: findings/summary.md is absent — the run produced no answer"; exit 1; }
  expected="$(printf '%s\n%s\n' "$SLICE1_TRUTH" "$SLICE2_TRUTH" | LC_ALL=C sort -u)"
  actual="$(items "$F/summary.md" "call sites" | norm)"
  echo "  summary listed: $(printf '%s\n' "$actual" | tr '\n' ' ')"
  compare_set "the coordinator summary" "$expected" "$actual" || fail=1
  ;;

slices)
  for n in 1 2; do
    file="$F/slice-$n.md"
    [ -s "$file" ] || { echo "FAIL: findings/slice-$n.md is absent or empty — that slice was not delivered"; fail=1; continue; }
    label="$(attributed "$file")"
    if [ -n "$label" ]; then
      echo "PASS: slice $n is attributed to delegate '$label'"
    else
      echo "FAIL: findings/slice-$n.md has no 'delegate:' attribution line"
      fail=1
    fi
    truth="SLICE${n}_TRUTH"
    compare_set "slice $n" "$(printf '%s\n' "${!truth}" | LC_ALL=C sort -u)" \
      "$(items "$file" "call sites" | norm)" || fail=1
  done
  if [ -s "$F/slice-1.md" ] && [ -s "$F/slice-2.md" ]; then
    label1="$(attributed "$F/slice-1.md")"
    label2="$(attributed "$F/slice-2.md")"
    if [ -n "$label1" ] && [ "$label1" = "$label2" ]; then
      echo "FAIL: both slices claim the same delegate '$label1' — the slices were not independently owned"
      fail=1
    elif cmp -s "$F/slice-1.md" "$F/slice-2.md"; then
      echo "FAIL: the two slice deliverables are byte-identical"
      fail=1
    else
      echo "PASS: the two slice deliverables are distinct and separately owned"
    fi
  fi
  ;;

isolation)
  manifest="$SPEC/judges/repo.sha256"
  [ -f "$manifest" ] || { echo "FAIL: held-out baseline manifest is missing"; exit 1; }
  cd "$ROOT" || { echo "FAIL: catalog $ROOT is unreadable"; exit 1; }
  if sha256sum -c --quiet "$manifest" >/dev/null 2>&1; then
    echo "PASS: every audited file matches the frozen baseline"
  else
    echo "FAIL: this audit is read-only but files under repo/ changed:"
    sha256sum -c "$manifest" 2>&1 | grep -v ': OK$' | sed 's/^/  /'
    fail=1
  fi
  extra="$(LC_ALL=C comm -13 \
    <(awk '{ print $2 }' "$manifest" | LC_ALL=C sort) \
    <(find repo -type f | LC_ALL=C sort) | tr '\n' ' ')"
  if [ -n "$extra" ]; then
    echo "FAIL: files were added under repo/: $extra"
    fail=1
  else
    echo "PASS: no files were added under repo/"
  fi
  ;;

delegation)
  case "$ARM" in
  st2)
    for worker in w1 w2; do
      if [ -n "$(messages_from "$worker" "sup")" ]; then
        echo "PASS: coordinator -> $worker delegation is on the bus"
      else
        echo "FAIL: no coordinator -> $worker delegation on the bus"
        fail=1
      fi
      if [ -n "$(messages_from "sup" "$worker")" ]; then
        echo "PASS: $worker -> coordinator report is on the bus"
      else
        echo "FAIL: no $worker -> coordinator report on the bus"
        fail=1
      fi
    done
    ;;
  native)
    log="$F/delegation-log.md"
    if [ -s "$log" ]; then
      labels="$(grep -cE '^[[:space:]]*delegate:[[:space:]]*[^[:space:]]' "$log")"
      if [ "$labels" -ge 2 ]; then
        echo "PASS: the native delegation log records $labels delegates (self-attested)"
      else
        echo "FAIL: findings/delegation-log.md records $labels delegates, expected one per slice"
        fail=1
      fi
    else
      echo "FAIL: findings/delegation-log.md is absent — no native delegation was recorded"
      fail=1
    fi
    peers="$(find "$BUS" -maxdepth 2 -type d -name inbox 2>/dev/null |
      sed 's#/inbox$##' | xargs -r -n1 basename | grep -vE '(^|\.)requester$' | LC_ALL=C sort -u)"
    count="$(printf '%s\n' "$peers" | grep -c .)"
    if [ "$count" -eq 1 ]; then
      echo "PASS: exactly one bus agent existed, so every delegate was harness-native ($peers)"
    else
      echo "FAIL: expected exactly one bus agent in a native arm, found $count: $(printf '%s' "$peers" | tr '\n' ' ')"
      fail=1
    fi
    ;;
  *)
    echo "FAIL: delegation mode needs an arm argument (st2|native), got '${ARM:-<none>}'"
    fail=1
    ;;
  esac
  ;;

*)
  echo "FAIL: unknown grade mode '$MODE'"
  fail=1
  ;;
esac

exit "$fail"
