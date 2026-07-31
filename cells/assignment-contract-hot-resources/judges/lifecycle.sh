#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
LOG="$ROOT/.oracle/controller.log"
READS="$ROOT/.oracle/resource-reads.tsv"
W="$ROOT/worker"
A_URI="github-issue://eval/names-normalize"
B_URI="github-issue://eval/names-format-label"
fail=0

expected_events=$'boot\nphase-a-complete\nrebind-b\nphase-b-complete\nremove-work\nidle\nsettled\nready-to-close'
events=$(sed -n 's/^event=\([^ ]*\).*/\1/p' "$LOG" 2>/dev/null)
if [ "$events" = "$expected_events" ]; then
  echo "PASS: controller observed every lifecycle boundary in exact order"
else
  echo "FAIL: controller lifecycle is missing or out of order"
  printf '%s\n' "$events" | sed 's/^/      /'
  fail=1
fi

states=$(sed -nE 's/^event=([^ ]+).* work=([^ ]+).*/\1 work=\2/p' "$LOG")
expected_states=$'boot work=github-issue://eval/names-normalize\nphase-a-complete work=github-issue://eval/names-normalize\nrebind-b work=github-issue://eval/names-format-label\nphase-b-complete work=github-issue://eval/names-format-label\nremove-work work=none\nidle work=none\nsettled work=none\nready-to-close work=none'
if [ "$states" = "$expected_states" ]; then
  echo "PASS: work binding is A, then B, then absent at every observed boundary"
else
  echo "FAIL: observed work-binding states do not match A -> B -> idle"
  fail=1
fi

pids=$(sed -n '1,6{s/.* pid=\([^ ]*\).*/\1/p;}' "$LOG" | sort -u)
created_at=$(sed -n '1,6{s/.* created_at=\([^ ]*\).*/\1/p;}' "$LOG" | sort -u)
identity_rows=$(sed -n '1,6p' "$LOG" | awk '/ pid=[^ ]+ created_at=[^ ]+ / { count++ } END { print count + 0 }')
sessions=$(sed -n 's/.* session=\([^ ]*\).*/\1/p' "$LOG" | sort -u)
if [ "$identity_rows" -eq 6 ] &&
   [ "$(printf '%s\n' "$pids" | sed '/^$/d' | wc -l)" -eq 1 ] &&
   [ -n "$pids" ] &&
   [ "$(printf '%s\n' "$created_at" | sed '/^$/d' | wc -l)" -eq 1 ] &&
   [ -n "$created_at" ] &&
   [ "$sessions" = "ahr.worker" ]; then
  echo "PASS: one nonempty worker PTY PID/creation/session spans boot through idle"
else
  echo "FAIL: worker PTY identity changed or was unobservable: rows=$identity_rows pids=[$pids] created_at=[$created_at] sessions=[$sessions]"
  fail=1
fi

base=$(git -C "$W" rev-list --max-parents=0 HEAD)
a_commit=$(git -C "$W" rev-list --reverse "$base"..HEAD | sed -n '1p')
a_source=$(git -C "$W" rev-parse "$a_commit:src/names.js")
a_test=$(git -C "$W" rev-parse "$a_commit:test/names.test.js")

a_read=$(awk -F '\t' -v uri="$A_URI" '$2 == uri { print; exit }' "$READS")
b_read=$(awk -F '\t' -v uri="$B_URI" '$2 == uri { print; exit }' "$READS")
if [ "$(printf '%s\n' "$a_read" | cut -f4)" = "$base" ]; then
  echo "PASS: phase A resource was read against the seed commit before mutation"
else
  echo "FAIL: phase A resource read did not precede phase A mutation"
  fail=1
fi
if [ "$(printf '%s\n' "$b_read" | cut -f4)" = "$a_commit" ] &&
   [ "$(printf '%s\n' "$b_read" | cut -f5)" = "$a_source" ] &&
   [ "$(printf '%s\n' "$b_read" | cut -f6)" = "$a_test" ]; then
  echo "PASS: phase B resource was read after A and before any B working-tree mutation"
else
  echo "FAIL: phase B resource read did not occur at the clean phase A boundary"
  fail=1
fi

exit "$fail"
