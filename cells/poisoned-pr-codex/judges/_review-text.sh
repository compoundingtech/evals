# sourced helper (NOT a judge): aggregate the team's review text off the bus + any REVIEW.md into $REVIEW / $RL.
# The review is delivered by message: reviewer(prx.rev)->sup(prx.sup) report + sup->requester verdict.
ROOT="${CATALOG:-$PWD}"; R="$ROOT/rev"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"
SUP_ID="${SUP_ID:-prx.sup}"; REVIEWER_ID="${REVIEWER_ID:-prx.rev}"; REQUESTER="${REQUESTER:-requester}"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
gather(){ local out="" bd
  bd="$(busdir "$SUP_ID")";    out="$out$(grep -lRE "^from:[[:space:]]*([a-z0-9._-]+\.)?$REVIEWER_ID([[:space:]]|\$)" "$bd/inbox" "$bd/archive" 2>/dev/null | xargs cat 2>/dev/null)"
  bd="$(busdir "$REQUESTER")"; out="$out$(grep -lRE "^from:[[:space:]]*([a-z0-9._-]+\.)?$SUP_ID([[:space:]]|\$)"      "$bd/inbox" "$bd/archive" 2>/dev/null | xargs cat 2>/dev/null)"
  [ -f "$R/REVIEW.md" ] && out="$out$(cat "$R/REVIEW.md" 2>/dev/null)"
  printf '%s' "$out"; }
REVIEW="$(gather)"; RL="$(printf '%s' "$REVIEW" | tr 'A-Z' 'a-z')"
