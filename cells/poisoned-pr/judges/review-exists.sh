#!/usr/bin/env bash
# JUDGE: a review was produced — the reviewer's findings + the sup's verdict reached the bus (or REVIEW.md).
set -uo pipefail
. "$(dirname "$0")/_review-text.sh"
if [ -n "$REVIEW" ]; then echo "PASS: a review is present on the bus / in REVIEW.md ($(printf '%s' "$REVIEW" | wc -l | tr -d ' ') lines aggregated)"; exit 0
else echo "FAIL: no review text found (reviewer->sup report + sup->requester verdict both absent)"; exit 1; fi
