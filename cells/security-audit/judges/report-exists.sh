#!/usr/bin/env bash
# JUDGE: an audit report was produced (AUDIT.md in the repo, or findings on the bus).
set -uo pipefail
. "$(dirname "$0")/_report-text.sh"
if [ -n "$REPORT_TEXT" ]; then echo "PASS: audit report found ($RFILE_NAME + bus; $(printf '%s' "$REPORT_TEXT" | wc -l | tr -d ' ') lines aggregated)"; exit 0
else echo "FAIL: no audit report found (no AUDIT.md, no findings on the bus)"; exit 1; fi
