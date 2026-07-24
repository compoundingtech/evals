#!/usr/bin/env bash
# JUDGE (hard): the report catches all 3 HIGH-severity planted vulns — V1 command-injection, V2
# path-traversal, V3 auth-bypass (fail-open). Missing any HIGH = FAIL. (Ground truth: VULNS.manifest.)
set -uo pipefail
. "$(dirname "$0")/_report-text.sh"; R="$REPORT_TEXT"
chk(){ local label="$1" fre="$2" kw="$3"
  if printf '%s' "$R" | grep -qiE "$fre" && printf '%s' "$R" | grep -qiE "$kw"; then echo "PASS: COVERED $label"; return 0
  else echo "FAIL: MISSED (high-severity) $label"; return 1; fi; }
fail=0
chk "V1 command-injection (backup.js/backupNote)"   "backup\.js|backupNote" "inject|exec|shell|command" || fail=1
chk "V2 path-traversal (notes.js/readNote)"          "notes\.js|readNote"    "travers|\.\./|path"        || fail=1
chk "V3 auth-bypass fail-open (auth.js/isAuthorized)" "auth\.js|isAuthorized" "bypass|fail.?open|!token|no token|missing token|empty token|without a token" || fail=1
exit "$fail"
