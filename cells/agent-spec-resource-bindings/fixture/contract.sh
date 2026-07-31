#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
spec="$net/agents/rb/worker/agent.kdl"
original_spec="$root/agent-spec-resource-bindings.original"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"

cp "$spec" "$original_spec"

cleanup() {
  if test -f "$spec"; then
    sed -i '/role "worker"/a\\  retired #true' "$spec" 2>/dev/null || true
    st2 up --once --catalog "$net" --host rb >/dev/null 2>&1 || true
    PTY_ROOT="$PTY_ROOT" pty rm rb.worker >/dev/null 2>&1 || true
    cp "$original_spec" "$spec"
  fi
}
trap cleanup EXIT

for case_name in \
  uri duplicate policy \
  json-uri json-duplicate json-policy \
  toml-uri toml-duplicate toml-policy
do
  output="$root/invalid-$case_name.out"
  set +e
  st2 validate --catalog "$root/invalid/$case_name" --host rb --strict >"$output" 2>&1
  exit_code="$?"
  set -e
  test "$exit_code" -ne 0
done
grep -Fq 'must be an exact absolute URI' "$root/invalid-uri.out"
grep -Fq "duplicate resource binding 'work'" "$root/invalid-duplicate.out"
grep -Fq 'unsupported property `access`' "$root/invalid-policy.out"
grep -Fq 'must be an exact absolute URI' "$root/invalid-json-uri.out"
grep -Fq "duplicate resource binding 'work'" "$root/invalid-json-duplicate.out"
grep -Fq 'unknown field `access`' "$root/invalid-json-policy.out"
grep -Fq 'must be an exact absolute URI' "$root/invalid-toml-uri.out"
grep -Fq 'duplicate key' "$root/invalid-toml-duplicate.out"
grep -Fq 'unknown field `access`' "$root/invalid-toml-policy.out"
echo "RESOURCE-STRICT-FAILURES-GREEN-c214"

st2 validate --catalog "$root/parity" --host rb --strict >/dev/null
st2 agents --catalog "$root/parity" --host rb --json >"$root/parity.json"
jq -e '
  length == 3 and
  [.[].identity] == ["rb.json", "rb.kdl", "rb.toml"] and
  ([.[].resources] | unique | length) == 1 and
  .[0].resources == [
    {
      "name": "context",
      "_tag": "vendor-specific-v7",
      "uri": "vendor+thing://authority/context%2Fone"
    },
    {
      "name": "work",
      "_tag": "github-issue",
      "uri": "github-issue://example/project/41?view=exact%20bytes"
    }
  ]
' "$root/parity.json" >/dev/null

st2 validate --catalog "$net" --host rb --strict >/dev/null
st2 agents --catalog "$net" --host rb --json >"$root/agents-before.json"
st2 agents --catalog "$net" --host rb --json >"$root/agents-repeat.json"
cmp "$root/agents-before.json" "$root/agents-repeat.json"
jq -e '
  length == 1 and
  .[0].identity == "rb.worker" and
  .[0].resources == [
    {
      "name": "context",
      "_tag": "vendor-specific-v7",
      "uri": "vendor+thing://authority/context%2Fone"
    },
    {
      "name": "work",
      "_tag": "github-issue",
      "uri": "github-issue://example/project/41?view=exact%20bytes"
    }
  ]
' "$root/agents-before.json" >/dev/null
echo "RESOURCE-INSPECTION-GREEN-c214"

st2 up --once --catalog "$net" --host rb >"$root/launch.out"
grep -Fq 'launched (1): rb.worker' "$root/launch.out"
before="$(
  PTY_ROOT="$PTY_ROOT" pty list --json |
    jq -cer '.[] | select(.name == "rb.worker" and .status == "running") | {name, pid, createdAt}'
)"
test -n "$before"

sed -i \
  's#resource "work" _tag="github-issue" uri="github-issue://example/project/41?view=exact%20bytes"#resource "work" _tag="github-pr" uri="github-pr://example/project/86?view=exact%20bytes"#' \
  "$spec"
sed -i \
  '/resource "context"/a\\  resource "terminal" _tag="pty" uri="pty://rb/rb.worker"' \
  "$spec"
st2 validate --catalog "$net" --host rb --strict >/dev/null
st2 up --once --catalog "$net" --host rb >"$root/adopt.out"
grep -Fq 'adopted (1): worker' "$root/adopt.out"
test -z "$(sed -n '/launched (/p;/torn down (/p' "$root/adopt.out")"
after="$(
  PTY_ROOT="$PTY_ROOT" pty list --json |
    jq -cer '.[] | select(.name == "rb.worker" and .status == "running") | {name, pid, createdAt}'
)"
test "$after" = "$before"

st2 agents --catalog "$net" --host rb --json >"$root/agents-after.json"
jq -e '
  .[0].resources == [
    {
      "name": "context",
      "_tag": "vendor-specific-v7",
      "uri": "vendor+thing://authority/context%2Fone"
    },
    {
      "name": "terminal",
      "_tag": "pty",
      "uri": "pty://rb/rb.worker"
    },
    {
      "name": "work",
      "_tag": "github-pr",
      "uri": "github-pr://example/project/86?view=exact%20bytes"
    }
  ]
' "$root/agents-after.json" >/dev/null
echo "RESOURCE-NONDISRUPTIVE-ADOPTION-GREEN-c214"

sed -i '/role "worker"/a\\  retired #true' "$spec"
st2 up --once --catalog "$net" --host rb >/dev/null
PTY_ROOT="$PTY_ROOT" pty rm rb.worker >/dev/null 2>&1 || true
cp "$original_spec" "$spec"
trap - EXIT
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq 'length')" -eq 0
echo "RESOURCE-CLEANUP-GREEN-c214"
