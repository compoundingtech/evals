#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
ORACLE="$ROOT/.oracle"
EVENTS="$ORACLE/handoff-events.tsv"
CHECKPOINT="$ORACLE/phase-2-precommit"
RESTART="$ORACLE/restart-identities.tsv"
PHASE1="$(git -C "$ROOT/repo" log --format='%H%x09%s' |
  awk -F'\t' '$2 == "feat: add label normalization" { print $1 }')"
fail=0

if [ -s "$CHECKPOINT" ] &&
   grep -Fqx 'agent=arh.b' "$CHECKPOINT" &&
   grep -Fqx "head=$PHASE1" "$CHECKPOINT" &&
   grep -Fq 'src/widget.js' "$CHECKPOINT" &&
   grep -Fq 'test/widget.test.js' "$CHECKPOINT" &&
   grep -Fq 'package.json' "$CHECKPOINT"; then
  echo "PASS: B reached an observable dirty pre-commit checkpoint"
else
  echo "FAIL: B's pre-commit checkpoint is absent or incomplete"
  fail=1
fi

pre_identity="$(awk -F'\t' '$1 == "phase=pre" { print }' "$RESTART" 2>/dev/null)"
post_identity="$(awk -F'\t' '$1 == "phase=post" { print }' "$RESTART" 2>/dev/null)"
field() {
  local line="$1" key="$2" part
  IFS=$'\t' read -ra parts <<<"$line"
  for part in "${parts[@]}"; do
    case "$part" in
      "$key"=*) printf '%s\n' "${part#*=}"; return ;;
    esac
  done
}
pre_name="$(field "$pre_identity" name)"
pre_pid="$(field "$pre_identity" pid)"
pre_created="$(field "$pre_identity" created_at)"
pre_session="$(field "$pre_identity" session)"
post_name="$(field "$post_identity" name)"
post_pid="$(field "$post_identity" pid)"
post_created="$(field "$post_identity" created_at)"
post_session="$(field "$post_identity" session)"
if [ "$(grep -c '^phase=pre	' "$RESTART" 2>/dev/null)" -eq 1 ] &&
   [ "$(grep -c '^phase=post	' "$RESTART" 2>/dev/null)" -eq 1 ] &&
   [ "$pre_name" = "arh.b" ] && [ "$post_name" = "arh.b" ] &&
   [[ "$pre_pid" =~ ^[1-9][0-9]*$ ]] && [[ "$post_pid" =~ ^[1-9][0-9]*$ ]] &&
   [ "$pre_pid" != "$post_pid" ] &&
   [ -n "$pre_created" ] && [ -n "$post_created" ] &&
   [ "$pre_created" != "$post_created" ] &&
   [ "$pre_session" = "$pre_name@$pre_created" ] &&
   [ "$post_session" = "$post_name@$post_created" ] &&
   [ "$pre_session" != "$post_session" ]; then
  echo "PASS: explicit st2 restart exposed distinct pre/post B PTY process and session identities"
else
  echo "FAIL: B PTY replacement identity evidence is absent, incomplete, or unchanged"
  fail=1
fi

pre="$(awk -F'\t' '$2 == "phase2-precommit" { print $1 }' "$EVENTS")"
replacement="$(awk -F'\t' '$2 == "b-replacement-observed" { print $1 }' "$EVENTS")"
commit="$(awk -F'\t' '$2 == "phase2-committed" { print $1 }' "$EVENTS")"
pre_head="$(awk -F'\t' '$2 == "phase2-precommit" { sub(/^head=/, "", $4); print $4 }' "$EVENTS")"
replacement_head="$(awk -F'\t' '$2 == "b-replacement-observed" { sub(/^head=/, "", $4); print $4 }' "$EVENTS")"
if [ -n "$pre" ] && [ -n "$replacement" ] && [ -n "$commit" ] &&
   [ "$pre" -lt "$replacement" ] && [ "$replacement" -lt "$commit" ] &&
   [ "$pre_head" = "$PHASE1" ] && [ "$replacement_head" = "$PHASE1" ]; then
  echo "PASS: the successor commit landed only after checkpoint and observed PTY replacement"
else
  echo "FAIL: recovery event order is not checkpoint -> replacement -> commit"
  fail=1
fi

if [ "$(wc -l <"$RESTART")" -eq 2 ] &&
   [ "$(grep -c $'\tb-replacement-observed\t' "$EVENTS")" -eq 1 ]; then
  echo "PASS: one pre/post replacement pair gates recovery exactly once"
else
  echo "FAIL: replacement evidence was duplicated or malformed"
  fail=1
fi

exit "$fail"
