#!/usr/bin/env bash
set -uo pipefail

ROOT="$CATALOG"
REPO="$ROOT/repo"
SPEC="$ROOT/agent-spec.kdl"
ORACLE="$ROOT/.oracle"
EVENTS="$ORACLE/handoff-events.tsv"
RESTART="$ORACLE/restart-identities.tsv"
URI="github-issue://eval/widget-normalization"
mkdir -p "$ORACLE"
: >"$EVENTS"

holders() {
  grep -B1 -F 'resource "work"' "$SPEC" | grep -oE 'agent "[ab]"' | tr '\n' ',' | sed 's/,$//'
}
record() {
  printf '%s\t%s\tholders=%s\thead=%s\n' \
    "$(date +%s%N)" "$1" "$(holders)" "$(git -C "$REPO" rev-parse HEAD 2>/dev/null || true)" >>"$EVENTS"
}
atomic_publish() {
  local source="$1" next="$SPEC.next"
  cp "$source" "$next"
  mv "$next" "$SPEC"
}
wait_for_subject() {
  local subject="$1"
  until git -C "$REPO" log --format='%s' 2>/dev/null | grep -Fqx "$subject"; do
    sleep 1
  done
}
busdir() {
  local id="$1" d
  d="$(ls -d "$ST_ROOT"/*."$id" "$ST_ROOT/$id" 2>/dev/null | head -1)"
  printf '%s\n' "${d:-$ST_ROOT/$id}"
}
wait_for_message() {
  local owner="$1" sender="$2" required="${3:-}" f
  owner="$(busdir "$owner")"
  while :; do
    for f in "$owner/inbox"/* "$owner/archive"/*; do
      [ -f "$f" ] || continue
      grep -Eq "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$sender([[:space:]]|\$)" "$f" || continue
      [ -z "$required" ] || grep -Fq "$required" "$f" || continue
      printf '%s\n' "$f"
      return
    done
    sleep 1
  done
}
pty_identity() {
  st2 pty ls --json 2>/dev/null |
    bun -e '
      const sessions = JSON.parse(await Bun.stdin.text())
      const worker = sessions.find((session) =>
        session.name === "arh.b" &&
        session.status === "running" &&
        session.pid &&
        session.createdAt
      )
      if (!worker) process.exit(1)
      const identity = `${worker.name}@${worker.createdAt}`
      process.stdout.write([worker.name, worker.pid, worker.createdAt, identity].join("\t"))
    '
}
capture_replacement() {
  local pre post attempt restart_command_pid restart_command_finished=false
  local pre_name pre_pid pre_created pre_session
  local post_name post_pid post_created post_session

  if ! pre="$(pty_identity)"; then
    echo "controller invariant failed: B has no observable running PTY before restart" >>"$EVENTS"
    exit 1
  fi
  IFS=$'\t' read -r pre_name pre_pid pre_created pre_session <<<"$pre"
  printf 'phase=pre\tname=%s\tpid=%s\tcreated_at=%s\tsession=%s\n' \
    "$pre_name" "$pre_pid" "$pre_created" "$pre_session" >"$RESTART"

  st2 pty restart -y --force arh.b </dev/null >"$ORACLE/restart-command.log" 2>&1 &
  restart_command_pid=$!

  for attempt in $(seq 1 300); do
    post="$(pty_identity 2>/dev/null || true)"
    if [ -n "$post" ] && [ "$post" != "$pre" ]; then
      IFS=$'\t' read -r post_name post_pid post_created post_session <<<"$post"
      if [ "$post_name" = "$pre_name" ] &&
         [ "$post_pid" != "$pre_pid" ] &&
         [ "$post_created" != "$pre_created" ] &&
         [ "$post_session" != "$pre_session" ]; then
        printf 'phase=post\tname=%s\tpid=%s\tcreated_at=%s\tsession=%s\n' \
          "$post_name" "$post_pid" "$post_created" "$post_session" >>"$RESTART"
        return
      fi
    fi
    if [ "$restart_command_finished" = false ] &&
       ! kill -0 "$restart_command_pid" 2>/dev/null; then
      if wait "$restart_command_pid"; then
        restart_command_finished=true
      else
        echo "controller invariant failed: forced B PTY restart command failed" >>"$EVENTS"
        exit 1
      fi
    fi
    sleep 0.2
  done

  echo "controller invariant failed: explicit B PTY restart did not expose a replacement" >>"$EVENTS"
  exit 1
}

kickoff="$(wait_for_message arh.ctrl requester)"
st2 message archive "$(basename "$kickoff")" --as arh.ctrl
record initial
st2 message send arh.sup --as arh.ctrl --subject "begin durable coordination" \
  -m "Begin coordinating the work declared in durable context. Treat worker reports as progress until terminal verification."
st2 message send arh.a --as arh.ctrl --subject "begin durable work" \
  -m "Begin the work currently declared in your durable context."
record kickoff-dispatched
wait_for_subject "feat: add label normalization"
record phase1-committed

atomic_publish "$PWD/agent-spec.none.kdl"
record a-revoked
if [ -n "$(holders)" ]; then
  echo "controller invariant failed: revocation revision still has a holder" >>"$EVENTS"
  exit 1
fi

atomic_publish "$PWD/agent-spec.b.kdl"
record b-granted
if [ "$(holders)" != 'agent "b"' ]; then
  echo "controller invariant failed: grant revision does not have only b" >>"$EVENTS"
  exit 1
fi

st2 message send arh.a --as arh.ctrl --subject "durable context changed" \
  -m "Durable context changed. Reconcile your own current declaration now."
st2 message send arh.b --as arh.ctrl --subject "durable context changed" \
  -m "Durable context changed. Reconcile your own current declaration now."
st2 message send arh.sup --as arh.ctrl --subject "handoff transition published" \
  -m "The revoke-before-grant resource transition is published. Wait for the successor holder report."
record transition-dinged

until [ -s "$ORACLE/phase-2-precommit" ]; do sleep 1; done
record phase2-precommit
capture_replacement
record b-replacement-observed
touch "$ORACLE/restart.release"

wait_for_subject "feat: normalize widget labels"
record phase2-committed
st2 message send arh.sup --as arh.ctrl --subject "terminal commit observed" \
  -m "The successor commit is observable. Verify the durable work and both worker reports, then report only to arh.ctrl."
record terminal-notice

phase1="$(git -C "$REPO" log --format='%H%x09%s' |
  awk -F'\t' '$2 == "feat: add label normalization" { print $1 }')"
phase2="$(git -C "$REPO" log --format='%H%x09%s' |
  awk -F'\t' '$2 == "feat: normalize widget labels" { print $1 }')"
terminal_token="HANDOFF_VERIFIED URI=$URI A_COMMIT=$phase1 B_COMMIT=$phase2 tests=pass clean"
verification="$(wait_for_message arh.ctrl arh.sup "HANDOFF_VERIFIED")"
record supervisor-verified

verified=true
[ "$(git -C "$REPO" rev-list --count "$(git -C "$REPO" rev-list --max-parents=0 HEAD)"..HEAD)" -eq 2 ] ||
  verified=false
[ "$(git -C "$REPO" rev-parse "$phase2^")" = "$phase1" ] || verified=false
git -C "$REPO" show -s --format='%B' "$phase1" | grep -Fqx 'Eval-Worker: arh.a' || verified=false
git -C "$REPO" show -s --format='%B' "$phase2" | grep -Fqx 'Eval-Worker: arh.b' || verified=false
(cd "$REPO" && bun test) >/dev/null 2>&1 || verified=false
[ -z "$(git -C "$REPO" status --porcelain)" ] || verified=false
grep -Fq "$phase1" "$verification" || grep -Fq "${phase1:0:7}" "$verification" || verified=false
grep -Fq "$phase2" "$verification" || grep -Fq "${phase2:0:7}" "$verification" || verified=false
grep -Eiq 'test|pass' "$verification" || verified=false
grep -Eiq 'clean' "$verification" || verified=false
[ "$(grep -Fxc "$terminal_token" "$verification")" -eq 1 ] || verified=false
[ "$(grep -Fc 'HANDOFF_VERIFIED' "$verification")" -eq 1 ] || verified=false

if [ "$verified" = true ]; then
  record requester-ready
  st2 message send requester --as arh.ctrl --subject "durable work verified" \
    -m "Verified complete: $URI; A commit $phase1 precedes B commit $phase2; supervisor evidence received; tests pass; worktree clean."
else
  record requester-failed
  st2 message send requester --as arh.ctrl --subject "durable work verification failed" \
    -m "Blocked: terminal verification did not satisfy the deterministic handoff oracle."
fi

while :; do sleep 3600; done
