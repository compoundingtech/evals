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

agent_block() {
  local file="$1" name="$2"
  awk -v name="$name" '
    $0 == "agent \"" name "\" {" { inside=1; depth=1; print; next }
    inside {
      print
      opens=gsub(/\{/, "{")
      closes=gsub(/\}/, "}")
      depth += opens - closes
      if (depth == 0) exit
    }
  ' "$file"
}
active_assignment() {
  agent_block "$1" "$2" | awk -v uri="$URI" '
    $0 == "  assignment \"active\" _tag=\"coding-task\" id=\"" uri "\" {" {
      if ((getline uses) > 0 &&
          uses == "    uses \"work\" \"source\" \"worklog\" \"delivery\"" &&
          (getline closing) > 0 &&
          closing == "  }") count++
    }
    END { print count + 0 }
  '
}
idle_assignment() {
  agent_block "$1" "$2" | grep -Fxc '  assignment "idle"'
}

shape_ok=true
for revision in "$INITIAL" "$NONE" "$SUCCESSOR"; do
  [ "$(grep -cE '^[[:space:]]*resource "' "$revision")" -eq 8 ] || shape_ok=false
  [ "$(grep -Fc "resource \"work\" _tag=\"github-issue\" uri=\"$URI\"" "$revision")" -eq 2 ] ||
    shape_ok=false
  [ "$(grep -cE '^[[:space:]]*assignment "' "$revision")" -eq 2 ] || shape_ok=false
  for agent in a b; do
    block="$(agent_block "$revision" "$agent")"
    [ "$(printf '%s\n' "$block" | grep -cE '^[[:space:]]*resource "')" -eq 4 ] || shape_ok=false
    [ "$(printf '%s\n' "$block" |
      grep -Fc "resource \"work\" _tag=\"github-issue\" uri=\"$URI\"")" -eq 1 ] ||
      shape_ok=false
    [ "$(printf '%s\n' "$block" |
      grep -Fc 'resource "source" _tag="worktree" uri="worktree://eval/widget"')" -eq 1 ] ||
      shape_ok=false
    [ "$(printf '%s\n' "$block" |
      grep -Fc 'resource "worklog" _tag="axe-worklog" uri="axe-worklog://eval/widget-normalization"')" -eq 1 ] ||
      shape_ok=false
    [ "$(printf '%s\n' "$block" |
      grep -Fc "resource \"delivery\" _tag=\"ding\" uri=\"ding://eval/arh.$agent\"")" -eq 1 ] ||
      shape_ok=false
    [ "$(printf '%s\n' "$block" | grep -cE '^[[:space:]]*assignment "')" -eq 1 ] ||
      shape_ok=false
  done
  grep -Eq '\b(focus|state)\b' "$revision" && shape_ok=false
  grep -Eq 'lease|progress|workflow|holder|acceptance|phase|status=' "$revision" && shape_ok=false
done
if [ "$shape_ok" = true ]; then
  echo "PASS: every revision retains tagged URI resources and one minimal Assignment per agent"
else
  echo "FAIL: an Agent Spec revision has the wrong Resource or Assignment shape"
  fail=1
fi

if [ "$(active_assignment "$INITIAL" a)" -eq 1 ] &&
   [ "$(idle_assignment "$INITIAL" b)" -eq 1 ] &&
   [ "$(idle_assignment "$NONE" a)" -eq 1 ] &&
   [ "$(idle_assignment "$NONE" b)" -eq 1 ] &&
   [ "$(idle_assignment "$SUCCESSOR" a)" -eq 1 ] &&
   [ "$(active_assignment "$SUCCESSOR" b)" -eq 1 ] &&
   [ "$(grep -Fc 'uses "work" "source" "worklog" "delivery"' "$INITIAL")" -eq 1 ] &&
   [ "$(grep -Fc 'uses "work" "source" "worklog" "delivery"' "$NONE")" -eq 0 ] &&
   [ "$(grep -Fc 'uses "work" "source" "worklog" "delivery"' "$SUCCESSOR")" -eq 1 ]; then
  echo "PASS: revisions encode A-active -> both-idle -> B-active with one stable Assignment ID"
else
  echo "FAIL: static revisions do not encode the exclusive Assignment handoff"
  fail=1
fi

if [ "$(idle_assignment "$SPEC" a)" -eq 1 ] &&
   [ "$(active_assignment "$SPEC" b)" -eq 1 ] &&
   [ "$(grep -Fc 'assignment "active"' "$SPEC")" -eq 1 ]; then
  echo "PASS: final durable contract leaves only B active"
else
  echo "FAIL: final durable contract does not leave exactly B active"
  fail=1
fi

if [ ! -s "$EVENTS" ]; then
  echo "FAIL: controller did not record Assignment handoff events"
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
  echo "PASS: A-active transitions through both-idle to B-active with no overlap"
else
  echo "FAIL: active-Assignment snapshots do not prove revoke-before-grant exclusivity"
  sed 's/^/      /' "$EVENTS"
  fail=1
fi

if grep -Eiq 'normalize|widget|phase[ -]?[12]|feat:' \
  "$CELL/task.md" "$CELL/assignment-contract-handoff-assignment.kdl"; then
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
  echo "FAIL: a successful resource read was undeclared or not selected by the active Assignment"
  printf '%s\n' "$successful" | sed 's/^/      /'
  fail=1
else
  echo "PASS: every successful read was declared and work reads were selected; denied attempts=$denied_count"
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
