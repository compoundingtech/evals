#!/usr/bin/env bash
# JUDGE (held out): the delegated implementation. Identical bytes in every arm of this task; the KDL passes the
# arm in, so the outcome oracle can never differ between arms.
#
#   grade.sh outcome            collision-safe slugs behave exactly as specified, old behaviour preserved
#   grade.sh suite              node --test is green in repo/
#   grade.sh regression         the delivered tests go RED against the frozen baseline implementation
#   grade.sh slices             the implementation deliverable exists and is attributed to a delegate
#   grade.sh isolation          only src/slug.js and test/ changed
#   grade.sh delegation <arm>   the arm's delegation evidence (bus peers for st2, native log for native)
#
# PASS = exit 0. Every mode prints its reasoning; judge stdout is only visible when a human runs the script.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
SPEC="${SPEC_DIR:-$PWD}"
BUS="${ST_ROOT:-$ROOT}"
F="$ROOT/findings"
R="$ROOT/repo"
MODE="${1:-outcome}"
ARM="${2:-}"

attributed() {
  awk '
    /^[[:space:]]*delegate:[[:space:]]*[^[:space:]]/ {
      sub(/^[[:space:]]*delegate:[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      print
      exit
    }
  ' "$1"
}

busdir() {
  local id="$1" d
  d="$(ls -d "$BUS"/*."$id" "$BUS/$id" 2>/dev/null | head -1)"
  printf '%s\n' "${d:-$BUS/$id}"
}

messages_from() {
  local owner from
  owner="$(busdir "$1")"
  from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" \
    "$owner/inbox" "$owner/archive" 2>/dev/null
}

fail=0

case "$MODE" in
outcome)
  [ -f "$R/src/slug.js" ] || { echo "FAIL: repo/src/slug.js is absent"; exit 1; }
  # Behavioural probes, blind to how the collision suffixes were implemented.
  probe="$(
    NOTEFLOW_REPO="$R" node --input-type=module -e "
      const { slugify, slugsFor } = await import(process.env.NOTEFLOW_REPO + '/src/slug.js');
      const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
      const collisions = slugsFor([
        { heading: 'Alpha' }, { heading: 'Alpha' }, { heading: 'Beta' }, { heading: 'Alpha' },
      ]);
      const blanks = slugsFor([{ heading: '' }, { heading: '  ' }]);
      const singles = slugsFor([{ heading: 'Alpha' }, { heading: 'Beta' }]);
      console.log('collisions', eq(collisions, ['alpha', 'alpha-2', 'beta', 'alpha-3']) ? 'OK' : 'BAD ' + JSON.stringify(collisions));
      console.log('blanks', eq(blanks, ['note', 'note-2']) ? 'OK' : 'BAD ' + JSON.stringify(blanks));
      console.log('singles', eq(singles, ['alpha', 'beta']) ? 'OK' : 'BAD ' + JSON.stringify(singles));
      console.log('slugify', (slugify('Hello World') === 'hello-world' && slugify('') === 'note' && slugify('  --Trim!!  ') === 'trim') ? 'OK' : 'BAD');
    " 2>&1
  )"
  echo "$probe" | sed 's/^/  /'
  for name in collisions blanks singles slugify; do
    if printf '%s\n' "$probe" | grep -qE "^$name OK$"; then
      echo "PASS: $name probe"
    else
      echo "FAIL: $name probe did not hold"
      fail=1
    fi
  done
  ;;

suite)
  if (cd "$R" && node --test >/dev/null 2>&1); then
    echo "PASS: node --test is green in repo/"
  else
    echo "FAIL: node --test is not green in repo/"
    (cd "$R" && node --test 2>&1 | tail -20 | sed 's/^/  /')
    fail=1
  fi
  ;;

regression)
  baseline="$SPEC/mutations/baseline-slug.js"
  [ -f "$baseline" ] || { echo "FAIL: held-out baseline implementation is missing"; exit 1; }
  scratch="$(mktemp -d)"
  trap 'rm -rf -- "$scratch"' EXIT
  cp -a "$R/." "$scratch/" || { echo "FAIL: could not copy repo/ for the replay"; exit 1; }
  cp "$baseline" "$scratch/src/slug.js"
  if (cd "$scratch" && node --test >/dev/null 2>&1); then
    echo "FAIL: the delivered tests are GREEN against the pre-change implementation — no real regression test"
    fail=1
  else
    echo "PASS: the delivered tests go RED against the pre-change implementation"
  fi
  ;;

slices)
  file="$F/slice-1.md"
  if [ -s "$file" ]; then
    label="$(attributed "$file")"
    if [ -n "$label" ]; then
      echo "PASS: the implementation report is attributed to delegate '$label'"
    else
      echo "FAIL: findings/slice-1.md has no 'delegate:' attribution line"
      fail=1
    fi
  else
    echo "FAIL: findings/slice-1.md is absent or empty — the delegate produced no report"
    fail=1
  fi
  if [ -s "$F/summary.md" ]; then
    echo "PASS: the coordinator summary exists"
  else
    echo "FAIL: findings/summary.md is absent — the coordinator recorded no verification"
    fail=1
  fi
  ;;

isolation)
  manifest="$SPEC/judges/repo.sha256"
  [ -f "$manifest" ] || { echo "FAIL: held-out baseline manifest is missing"; exit 1; }
  cd "$ROOT" || { echo "FAIL: catalog $ROOT is unreadable"; exit 1; }
  # Only the declared slice may move: repo/src/slug.js and anything under repo/test/.
  changed="$(sha256sum -c "$manifest" 2>/dev/null | grep -v ': OK$' | sed 's/:.*$//' | LC_ALL=C sort -u)"
  echo "  changed or missing: $(printf '%s\n' "$changed" | tr '\n' ' ')"
  outside="$(printf '%s\n' "$changed" | grep -vE '^(repo/src/slug\.js|repo/test/)' | grep . | tr '\n' ' ')"
  if [ -n "$outside" ]; then
    echo "FAIL: files outside the declared slice changed: $outside"
    fail=1
  else
    echo "PASS: nothing outside repo/src/slug.js and repo/test/ changed"
  fi
  if printf '%s\n' "$changed" | grep -q '^repo/src/slug\.js$'; then
    echo "PASS: repo/src/slug.js was actually changed"
  else
    echo "FAIL: repo/src/slug.js is unchanged — the feature was not implemented"
    fail=1
  fi
  gone="$(LC_ALL=C comm -23 \
    <(awk '{ print $2 }' "$manifest" | LC_ALL=C sort) \
    <(find repo -type f | LC_ALL=C sort) | grep . | tr '\n' ' ')"
  if [ -n "$gone" ]; then
    echo "FAIL: baseline files were deleted: $gone"
    fail=1
  else
    echo "PASS: no baseline file was deleted"
  fi
  added="$(LC_ALL=C comm -13 \
    <(awk '{ print $2 }' "$manifest" | LC_ALL=C sort) \
    <(find repo -type f | LC_ALL=C sort) | grep -vE '^repo/test/' | grep . | tr '\n' ' ')"
  if [ -n "$added" ]; then
    echo "FAIL: files were added outside repo/test/: $added"
    fail=1
  else
    echo "PASS: no files were added outside repo/test/"
  fi
  ;;

delegation)
  case "$ARM" in
  st2)
    if [ -n "$(messages_from "w1" "sup")" ]; then
      echo "PASS: coordinator -> w1 delegation is on the bus"
    else
      echo "FAIL: no coordinator -> w1 delegation on the bus"
      fail=1
    fi
    if [ -n "$(messages_from "sup" "w1")" ]; then
      echo "PASS: w1 -> coordinator report is on the bus"
    else
      echo "FAIL: no w1 -> coordinator report on the bus"
      fail=1
    fi
    ;;
  native)
    log="$F/delegation-log.md"
    if [ -s "$log" ]; then
      labels="$(grep -cE '^[[:space:]]*delegate:[[:space:]]*[^[:space:]]' "$log")"
      if [ "$labels" -ge 1 ]; then
        echo "PASS: the native delegation log records $labels delegate(s) (self-attested)"
      else
        echo "FAIL: findings/delegation-log.md records no delegate"
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
