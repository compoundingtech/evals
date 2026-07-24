#!/usr/bin/env bash
# JUDGE: full migration breadth — greetkit really on 2.0.0, no old-API refs linger, every call site fixed.
# (A locally-defined behavior-preserving adapter is fine; a lingering greetkit-v1 import or a greetAll call
# is a defect.)
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
fail=0
grep -qE "greetAll\(" "$W/src/app.js" 2>/dev/null && { echo "FAIL: greetAll still CALLED in src/ (removed in 2.0.0)"; fail=1; } || echo "PASS: no greetAll call in src/ (comments are fine)"
impline=$(grep -E "import .* from \"[^\"]*greetkit" "$W/src/app.js" 2>/dev/null | head -1)
echo "$impline" | grep -qE "\bgreetAll\b|\bfarewell\b" && { echo "FAIL: greetkit import still pulls a v1 name (greetAll/farewell): $impline"; fail=1; } || echo "PASS: greetkit import uses only v2 API"
tot=$(grep -oE "greetFormal\(" "$W/src/app.js" 2>/dev/null | wc -l | tr -d ' '); obj=$(grep -oE "greetFormal\(\{" "$W/src/app.js" 2>/dev/null | wc -l | tr -d ' ')
{ [ "$tot" -gt 0 ] && [ "$tot" = "$obj" ]; } && echo "PASS: all $tot greetFormal call(s) use v2 object-arg" || { echo "FAIL: greetFormal object-arg: $obj/$tot (positional remain)"; fail=1; }
imp=$(grep -oE 'from "\.\.?/[^"]*greetkit[^"]*"' "$W/src/app.js" 2>/dev/null | head -1 | sed 's/from "//; s/"$//')
gkdir=$(cd "$W/src" && cd "$(dirname "$imp")" && pwd 2>/dev/null)
V=$(node -e "console.log(require('$gkdir/package.json').version)" 2>/dev/null)
[ "$V" = "2.0.0" ] && echo "PASS: greetkit the app imports ($imp) is 2.0.0" || { echo "FAIL: imported greetkit version='$V' (want 2.0.0; import=$imp)"; fail=1; }
grep -qE "export function (greetAll|farewell)" "$gkdir/index.js" 2>/dev/null && { echo "FAIL: imported greetkit still exports v1 API (shim / not really migrated)"; fail=1; } || echo "PASS: imported greetkit exports no v1 API"
exit "$fail"
