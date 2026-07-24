#!/usr/bin/env bash
# JUDGE: coverage signals (non-gating) — the mediums/low SHOULD be caught, and the red-herrings should NOT
# be flagged as real vulns (false-positive discipline; human read finalizes severity/FP).
set -uo pipefail
. "$(dirname "$0")/_report-text.sh"; R="$REPORT_TEXT"
sig(){ local label="$1" fre="$2" kw="$3"; { printf '%s' "$R" | grep -qiE "$fre" && printf '%s' "$R" | grep -qiE "$kw"; } && echo "  ok: covered $label" || echo "  WARN: missed $label"; }
sig "V4 hardcoded-secret (config.js/API_TOKEN)"     "config\.js|API_TOKEN"       "secret|hardcod|credential|apptoken"
sig "V5 regex-injection/ReDoS (search.js)"          "search\.js|searchNotes"     "redos|regex|regexp|catastrophic"
sig "V6 weak-random token (tokens.js)"              "tokens\.js|newSessionToken" "random|predictab|insecure|cryptograph"
for rh in randomTip evaluate; do printf '%s' "$R" | grep -qi "$rh" && echo "  info: report mentions red-herring '$rh' — dismissed=good, flagged-as-vuln=FP (human read)" || echo "  info: red-herring '$rh' not mentioned"; done
exit 0
