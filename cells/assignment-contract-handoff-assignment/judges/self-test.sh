#!/usr/bin/env bash
set -euo pipefail

CELL="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/.oracle" "$SANDBOX/repo/src" "$SANDBOX/repo/test"

SPECS=("$CELL"/*.kdl)
CONTROLLER="$CELL/fixture/controller/handoff-controller.sh"
CONTRACT="$CELL/judges/contract.sh"
if [ "${#SPECS[@]}" -ne 1 ] ||
   grep -Eq '^[[:space:]]*supervise[[:space:]]*$' "${SPECS[0]}" ||
   ! grep -Fq 'st2 pty restart -y --force arh.b </dev/null >"$ORACLE/restart-command.log" 2>&1 &' "$CONTROLLER" ||
   grep -Eq 'st2 pty restart -y arh\.b' "$CONTROLLER" ||
   grep -Fq 'st2 pty kill arh.b' "$CONTROLLER"; then
  echo "FAIL: restart topology is not explicit and B-only"
  exit 1
fi
if ! grep -Fq 'wait_for_message arh.ctrl arh.sup "HANDOFF_VERIFIED"' "$CONTROLLER" ||
   grep -Fq 'wait_for_message arh.ctrl arh.sup "$URI"' "$CONTROLLER" ||
   ! grep -Fq 'grep -Fxc "$terminal_token" "$verification"' "$CONTROLLER"; then
  echo "FAIL: controller can accept a non-terminal supervisor progress report"
  exit 1
fi
phase1_token="$(printf '1%.0s' {1..40})"
phase2_token="$(printf '2%.0s' {1..40})"
terminal_token="HANDOFF_VERIFIED URI=github-issue://eval/widget-normalization A_COMMIT=$phase1_token B_COMMIT=$phase2_token tests=pass clean"
phase1_progress="URI=github-issue://eval/widget-normalization A_COMMIT=$phase1_token tests=pass clean"
if printf '%s\n' "$phase1_progress" | grep -Fqx "$terminal_token" ||
   ! printf '%s\n' "$terminal_token" | grep -Fqx "$terminal_token"; then
  echo "FAIL: terminal token mutation oracle is not sharp"
  exit 1
fi
if grep -Fq 'grep -vq '\''"permitted":true'\''' "$CONTRACT" ||
   ! grep -Fq 'denied_count=' "$CONTRACT"; then
  echo "FAIL: contract judge still treats a denied attempt as an access violation"
  exit 1
fi
ready_line="$(grep -nF 'record requester-ready' "$CONTROLLER" | cut -d: -f1)"
send_line="$(grep -nF 'st2 message send requester --as arh.ctrl --subject "durable work verified"' "$CONTROLLER" |
  cut -d: -f1)"
if [ -z "$ready_line" ] || [ -z "$send_line" ] || [ "$ready_line" -ge "$send_line" ]; then
  echo "FAIL: requester-ready is not durable before final delivery"
  exit 1
fi

BUS="$SANDBOX/bus"
ST_ROOT="$BUS" st2 message send receiver --as sender --subject "durable context changed" \
  -m "Durable context changed. Reconcile your own current declaration now." >/dev/null
MESSAGES=("$BUS/receiver/inbox/"*)
if [ "${#MESSAGES[@]}" -ne 1 ] ||
   ! grep -Fxq 'subject: durable context changed' "${MESSAGES[0]}" ||
   grep -Fq 'subject: "durable context changed"' "${MESSAGES[0]}"; then
  echo "FAIL: st2 transition subject is not matched in canonical serialized form"
  exit 1
fi

mkdir -p "$SANDBOX/bin" "$SANDBOX/resources"
cp "$CELL/fixture/bin/resource-read" "$SANDBOX/bin/resource-read"
cp "$CELL/fixture/agent-spec.kdl" "$SANDBOX/agent-spec.kdl"
cp "$CELL/fixture/resources/work.md" "$SANDBOX/resources/work.md"
if ST_AGENT=arh.b "$SANDBOX/bin/resource-read" \
  github-issue://eval/widget-normalization >/dev/null 2>&1; then
  echo "FAIL: inactive successor unexpectedly resolved the work resource"
  exit 1
else
  denied_status=$?
fi
if [ "$denied_status" -ne 66 ] ||
   ! grep -Fq '"agent":"arh.b"' "$SANDBOX/.oracle/resource-reads.jsonl" ||
   ! grep -Fq '"permitted":false' "$SANDBOX/.oracle/resource-reads.jsonl"; then
  echo "FAIL: denied resource attempt was not rejected and audited"
  exit 1
fi

git -C "$SANDBOX/repo" init -q
git -C "$SANDBOX/repo" config user.name "schickling-assistant"
git -C "$SANDBOX/repo" config user.email "261620128+schickling-assistant@users.noreply.github.com"
printf 'export const widget = true\n' >"$SANDBOX/repo/src/widget.js"
printf '{"scripts":{"test":"true"}}\n' >"$SANDBOX/repo/package.json"
git -C "$SANDBOX/repo" add .
git -C "$SANDBOX/repo" commit -q -m "feat: add label normalization"
PHASE1="$(git -C "$SANDBOX/repo" rev-parse HEAD)"

printf 'export const widget = false\n' >"$SANDBOX/repo/src/widget.js"
printf 'test\n' >"$SANDBOX/repo/test/widget.test.js"
printf '{"scripts":{"test":"bun test"}}\n' >"$SANDBOX/repo/package.json"
{
  printf 'agent=arh.b\n'
  printf 'head=%s\n' "$PHASE1"
  printf 'status:\n'
  printf ' M src/widget.js\n'
  printf ' M package.json\n'
  printf '?? test/widget.test.js\n'
} >"$SANDBOX/.oracle/phase-2-precommit"
{
  printf '1\tphase2-precommit\tholders=agent "b"\thead=%s\n' "$PHASE1"
  printf '2\tb-replacement-observed\tholders=agent "b"\thead=%s\n' "$PHASE1"
  printf '3\tphase2-committed\tholders=agent "b"\thead=synthetic-phase-2\n'
} >"$SANDBOX/.oracle/handoff-events.tsv"
{
  printf 'phase=pre\tname=arh.b\tpid=4101\tcreated_at=2026-07-30T10:00:00.000Z\tsession=arh.b@2026-07-30T10:00:00.000Z\n'
  printf 'phase=post\tname=arh.b\tpid=4202\tcreated_at=2026-07-30T10:01:00.000Z\tsession=arh.b@2026-07-30T10:01:00.000Z\n'
} >"$SANDBOX/.oracle/restart-identities.tsv"

CATALOG="$SANDBOX" bash "$CELL/judges/recovery.sh" >/dev/null

sed -n '1p' "$SANDBOX/.oracle/restart-identities.tsv" >"$SANDBOX/.oracle/restart-identities.failed"
mv "$SANDBOX/.oracle/restart-identities.failed" "$SANDBOX/.oracle/restart-identities.tsv"
if CATALOG="$SANDBOX" bash "$CELL/judges/recovery.sh" >/dev/null 2>&1; then
  echo "FAIL: missing post-kill identity evidence passed"
  exit 1
fi

{
  printf 'phase=pre\tname=arh.b\tpid=4101\tcreated_at=2026-07-30T10:00:00.000Z\tsession=arh.b@2026-07-30T10:00:00.000Z\n'
  printf 'phase=post\tname=arh.b\tpid=4101\tcreated_at=2026-07-30T10:00:00.000Z\tsession=arh.b@2026-07-30T10:00:00.000Z\n'
} >"$SANDBOX/.oracle/restart-identities.tsv"
if CATALOG="$SANDBOX" bash "$CELL/judges/recovery.sh" >/dev/null 2>&1; then
  echo "FAIL: unchanged PTY identity passed"
  exit 1
fi

echo "PASS: terminal, denied-read, and replacement-evidence mutations are rejected sharply"
