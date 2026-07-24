#!/usr/bin/env bash
# JUDGE: completeness signals — keyword proxies for the 3 load-bearing contracts + the return shape.
# These are NON-GATING signals (surfaced for the reviewer); the DEFINITIVE completeness/usability test is
# the held-out cold-reader (judges/cold-reader.sh), which actually uses the docs to compute a total.
#
# PASS (exit 0): always — this judge only reports signals. A missing signal is a WARN, not a failure.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
BODY=$(cd "$W" && cat README.md $(find docs -type f 2>/dev/null) 2>/dev/null)
sig(){ local label="$1" re="$2"; printf '%s' "$BODY" | grep -qiE "$re" && echo "  ok: documents $label" || echo "  WARN: MISSING signal: $label (a cold reader may trip)"; }
sig "C1a integer CENTS convention"             "cent"
sig "C1b tax in BASIS POINTS"                  "basis point|\bbps\b|/ ?10000|10,?000"
sig "C2 immutable/return-new (use the return)" "immutab|returns a new|new cart|does not mutate|use the returned|reassign|chain"
sig "C3 seal() before total()"                 "seal"
sig "return shape fields"                      "subtotalCents|discountCents|taxCents|totalCents"
exit 0
