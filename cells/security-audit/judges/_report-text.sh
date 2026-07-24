# sourced helper (NOT a judge): aggregate the audit report — AUDIT.md in the repo + the auditor's findings
# on the bus (sa.aud->sa.sup + sa.sup->requester) — into $REPORT_TEXT.
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"
SUP_ID="${SUP_ID:-sa.sup}"; AUD_ID="${AUD_ID:-sa.aud}"; REQUESTER="${REQUESTER:-requester}"
RFILE=$(ls "$W"/AUDIT.md "$W"/audit.md "$W"/AUDIT.MD 2>/dev/null | head -1)
[ -z "$RFILE" ] && RFILE=$(grep -rilE "vulnerab|audit|finding" "$W" --include=*.md 2>/dev/null | grep -iv node_modules | grep -iv readme | head -1)
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
gather(){ local out="" bd
  [ -n "$RFILE" ] && out="$out$(cat "$RFILE" 2>/dev/null)"
  bd="$(busdir "$SUP_ID")";    out="$out$(grep -lRE "^from:[[:space:]]*([a-z0-9._-]+\.)?$AUD_ID([[:space:]]|\$)" "$bd/inbox" "$bd/archive" 2>/dev/null | xargs cat 2>/dev/null)"
  bd="$(busdir "$REQUESTER")"; out="$out$(grep -lRE "^from:[[:space:]]*([a-z0-9._-]+\.)?$SUP_ID([[:space:]]|\$)"  "$bd/inbox" "$bd/archive" 2>/dev/null | xargs cat 2>/dev/null)"
  printf '%s' "$out"; }
REPORT_TEXT="$(gather)"; RFILE_NAME=$(basename "${RFILE:-none}")
