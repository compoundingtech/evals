#!/usr/bin/env bash
set -euo pipefail

conflict="${CATALOG:?CATALOG must be set}/conflict/shared"
equivalent="$CATALOG/equivalent/shared"

test ! -e "$conflict/.st2/PERSONA.md"
echo "FULL-CONFLICT-PREWRITE-GREEN-95"

test ! -e "$conflict/.st2/PERSONA.md"
echo "TARGETED-CONFLICT-PREWRITE-GREEN-95"

test "$(cat "$equivalent/.st2/bus.md")" = "shared-bus"
echo "EQUIVALENT-SHARED-GREEN-95"
