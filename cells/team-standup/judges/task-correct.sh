#!/usr/bin/env bash
# JUDGE: task correct (held-out) — wordCount BEHAVES per SPEC.md on cases the visible suite never covers:
# the empty string, an all-whitespace string, tabs/newlines as separators, and leading/trailing whitespace.
# Behavior only — any correct implementation passes, and the visible suite must still be green.
#
# PASS (exit 0): the visible suite passes and every held-out case returns the specified count.
set -uo pipefail
W="${CATALOG:-$PWD}/widget"
[ -d "$W" ] || { echo "FAIL: no widget repo at $W — did the run happen?"; exit 1; }
command -v node >/dev/null || { echo "FAIL: node is required to grade this cell"; exit 1; }

fail=0
if (cd "$W" && node --test >/dev/null 2>&1); then
  echo "PASS: the visible suite is green"
else
  echo "FAIL: the visible suite is red"
  fail=1
fi

held_out="$(cd "$W" && node --input-type=module -e '
  const { wordCount } = await import("./src/count.js");
  const cases = [["", 0], ["   ", 0], ["\t\n ", 0], ["one", 1], [" a  b\tc ", 3], ["a\nb\nc\nd", 4]];
  const bad = [];
  for (const [input, want] of cases) {
    let got;
    try { got = wordCount(input); } catch (e) { got = "threw: " + e.message; }
    if (got !== want) bad.push(JSON.stringify(input) + " -> " + JSON.stringify(got) + ", want " + want);
  }
  if (bad.length) { console.log(bad.join("; ")); process.exit(1); }
' 2>&1)"
if [ -z "$held_out" ]; then
  echo "PASS: every held-out case matches SPEC.md"
else
  echo "FAIL: held-out cases disagree with SPEC.md — $held_out"
  fail=1
fi

exit "$fail"
