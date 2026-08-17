#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
CELL="${EVAL_CELL:-$PWD}"
SPEC="$ROOT/agent-spec.kdl"
INITIAL="$CELL/fixture/agent-spec.kdl"
NONE="$ROOT/controller/agent-spec.none.kdl"
SUCCESSOR="$ROOT/controller/agent-spec.b.kdl"
EVENTS="$ROOT/.oracle/handoff-events.tsv"
READS="$ROOT/.oracle/resource-reads.jsonl"
URI="github-issue://eval/widget-normalization"
fail=0

if grep -Eiq '\b(assignment|holder|state)\b' "$SPEC" "$INITIAL" "$NONE" "$SUCCESSOR"; then
  echo "FAIL: focus Agent Spec revisions contain an assignment, holder, or state wrapper"
  fail=1
else
  echo "PASS: all Agent Spec revisions use named tagged resources plus focus"
fi

initial_a="$(awk '/agent "a" \{/,/^}/' "$INITIAL" | grep -Fc "resource \"work\" uri=\"$URI\"")"
initial_b="$(awk '/agent "b" \{/,/^}/' "$INITIAL" | grep -Fc "resource \"work\" uri=\"$URI\"")"
initial_a_focus="$(awk '/agent "a" \{/,/^}/' "$INITIAL" | grep -Fc 'focus "work"')"
initial_b_focus="$(awk '/agent "b" \{/,/^}/' "$INITIAL" | grep -Fc 'focus "work"')"
none_work="$(grep -Fc "resource \"work\" uri=\"$URI\"" "$NONE")"
none_focus="$(grep -Fc 'focus "work"' "$NONE")"
successor_a="$(awk '/agent "a" \{/,/^}/' "$SUCCESSOR" |
  grep -Fc "resource \"work\" uri=\"$URI\"")"
successor_b="$(awk '/agent "b" \{/,/^}/' "$SUCCESSOR" |
  grep -Fc "resource \"work\" uri=\"$URI\"")"
successor_a_focus="$(awk '/agent "a" \{/,/^}/' "$SUCCESSOR" | grep -Fc 'focus "work"')"
successor_b_focus="$(awk '/agent "b" \{/,/^}/' "$SUCCESSOR" | grep -Fc 'focus "work"')"
if [ "$initial_a" -eq 1 ] && [ "$initial_b" -eq 1 ] &&
   [ "$initial_a_focus" -eq 1 ] && [ "$initial_b_focus" -eq 0 ] &&
   [ "$none_work" -eq 2 ] && [ "$none_focus" -eq 0 ] &&
   [ "$successor_a" -eq 1 ] && [ "$successor_b" -eq 1 ] &&
   [ "$successor_a_focus" -eq 0 ] && [ "$successor_b_focus" -eq 1 ]; then
  echo "PASS: revisions retain the same URI for both workers and encode A focus -> none -> B focus"
else
  echo "FAIL: static Agent Spec revisions do not encode the focus-selected exclusive handoff"
  fail=1
fi

if [ "$(grep -Fc "resource \"work\" uri=\"$URI\"" "$SPEC")" -eq 2 ] &&
   ! awk '/agent "a" \{/,/^}/' "$SPEC" | grep -Fq 'focus "work"' &&
   awk '/agent "b" \{/,/^}/' "$SPEC" | grep -Fq 'focus "work"'; then
  echo "PASS: final graph retains the stable work URI and focuses only B"
else
  echo "FAIL: final graph does not retain both work resources while focusing only B"
  fail=1
fi

if [ ! -s "$EVENTS" ]; then
  echo "FAIL: controller did not record resource-graph events"
  exit 1
fi

event_names="$(cut -f2 "$EVENTS" | tr '\n' ' ')"
expected="initial kickoff-dispatched phase1-committed a-revoked b-granted transition-dinged phase2-precommit b-replacement-observed phase2-committed terminal-notice supervisor-verified requester-ready "
if [ "$event_names" = "$expected" ]; then
  echo "PASS: controller events form the expected handoff and recovery sequence"
else
  echo "FAIL: unexpected controller event sequence: $event_names"
  fail=1
fi

initial_holders="$(awk -F'\t' '$2 == "initial" { print $3 }' "$EVENTS")"
revoked_holders="$(awk -F'\t' '$2 == "a-revoked" { print $3 }' "$EVENTS")"
granted_holders="$(awk -F'\t' '$2 == "b-granted" { print $3 }' "$EVENTS")"
if [ "$initial_holders" = 'holders=agent "a"' ] &&
   [ "$revoked_holders" = "holders=" ] &&
   [ "$granted_holders" = 'holders=agent "b"' ] &&
   ! grep -Fq 'agent "a",agent "b"' "$EVENTS"; then
  echo "PASS: A-only transitions through no holder to B-only with no overlap"
else
  echo "FAIL: holder snapshots do not prove revoke-before-grant exclusivity"
  sed 's/^/      /' "$EVENTS"
  fail=1
fi

if grep -Eiq 'normalize|widget|phase[ -]?[12]|feat:' \
  "$CELL/task.md" "$CELL/assignment-contract-handoff-focus.kdl"; then
  echo "FAIL: product task facts leaked into kickoff or model command"
  fail=1
else
  echo "PASS: kickoff and model commands contain no product task facts"
fi

if [ ! -s "$READS" ]; then
  echo "FAIL: resource resolver has no audit log"
  exit 1
fi
successful="$(grep -F '"permitted":true' "$READS" || true)"
denied_count="$(grep -Fc '"permitted":false' "$READS" || true)"
if printf '%s\n' "$successful" | grep -Fq '"declared":false' ||
   printf '%s\n' "$successful" |
     grep -F '"uri":"github-issue://eval/widget-normalization"' |
     grep -Fq '"work_bound":false'; then
  echo "FAIL: a successful resource read was undeclared or not focused as work"
  printf '%s\n' "$successful" | sed 's/^/      /'
  fail=1
else
  echo "PASS: every successful read was declared and work reads were focused; denied attempts=$denied_count"
fi

base="$(git -C "$ROOT/repo" rev-list --max-parents=0 HEAD)"
phase1="$(git -C "$ROOT/repo" log --format='%H%x09%s' | awk -F'\t' '$2 == "feat: add label normalization" { print $1 }')"
a_work="$(grep -F '"agent":"arh.a"' "$READS" | grep -F "\"uri\":\"$URI\"" |
  grep -F '"permitted":true' || true)"
b_work="$(grep -F '"agent":"arh.b"' "$READS" | grep -F "\"uri\":\"$URI\"" |
  grep -F '"permitted":true' || true)"
if [ "$(printf '%s\n' "$a_work" | sed '/^$/d' | wc -l)" -ge 1 ] &&
   printf '%s\n' "$a_work" | grep -Fq "\"head\":\"$base\"" &&
   [ "$(printf '%s\n' "$b_work" | sed '/^$/d' | wc -l)" -ge 1 ] &&
   printf '%s\n' "$b_work" | grep -Fq "\"head\":\"$phase1\""; then
  echo "PASS: A and B resolved the same work URI at their respective committed boundaries"
else
  echo "FAIL: resolver log does not show the same work URI moving from A to B"
  fail=1
fi

b_work_sequence="$(printf '%s\n' "$b_work" | sed -n '1p' | cut -d: -f2 | cut -d, -f1)"
b_worklog="$(grep -F '"agent":"arh.b"' "$READS" |
  grep -F '"uri":"axe-worklog://eval/widget-normalization"' |
  grep -F '"permitted":true' | sed -n '1p' || true)"
b_source="$(grep -F '"agent":"arh.b"' "$READS" |
  grep -F '"uri":"worktree://eval/widget"' |
  grep -F '"permitted":true' | sed -n '1p' || true)"
b_worklog_sequence="$(printf '%s\n' "$b_worklog" | cut -d: -f2 | cut -d, -f1)"
b_source_sequence="$(printf '%s\n' "$b_source" | cut -d: -f2 | cut -d, -f1)"
if [ -n "$b_work_sequence" ] && [ -n "$b_worklog_sequence" ] && [ -n "$b_source_sequence" ] &&
   [ "$b_work_sequence" -lt "$b_worklog_sequence" ] &&
   [ "$b_work_sequence" -lt "$b_source_sequence" ]; then
  echo "PASS: B resolved work first, then the declared worklog and worktree resources"
else
  echo "FAIL: B did not resolve work before both continuity resources"
  fail=1
fi

exit "$fail"
