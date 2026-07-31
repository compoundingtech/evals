#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
alpha_spec="$net/agents/ap/alpha/agent.kdl"
beta_spec="$net/agents/ap/beta/agent.kdl"
alpha_original="$root/alpha.original.kdl"
beta_original="$root/beta.original.kdl"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"

cp "$alpha_spec" "$alpha_original"
cp "$beta_spec" "$beta_original"

pty_at() {
  env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" pty "$@"
}

session() {
  id="$1"
  pty_at list --json | jq -cer --arg id "$id" '.[] | select(.name == $id)'
}

generation() {
  session "$1" | jq -c '{name,pid,createdAt}'
}

presentation() {
  session "$1" | jq -c '{displayName,tags}'
}

event_count() {
  id="$1"
  type="$2"
  jq -s --arg type "$type" '[.[] | select(.type == $type)] | length' "$PTY_ROOT/$id.events.jsonl"
}

last_metadata_event() {
  local id="$1"
  jq -cs '[.[] | select(.type == "metadata_change")] | last' "$PTY_ROOT/$id.events.jsonl"
}

wait_running() {
  id="$1"
  for _ in $(seq 1 100); do
    test "$(session "$id" | jq -r '.status')" = running && return 0
    sleep 0.05
  done
  printf '%s did not become ready\n' "$id" >&2
  return 1
}

retire() {
  spec="$1"
  grep -Fq 'retired #true' "$spec" || sed -i '/role "worker"/a\\  retired #true' "$spec"
}

cleanup() {
  for spec in "$alpha_spec" "$beta_spec"; do
    test ! -f "$spec" || retire "$spec" 2>/dev/null || true
  done
  st2 up --once --catalog "$net" --host ap >/dev/null 2>&1 || true
  for id in ap.alpha ap.alpha.helper ap.beta; do
    pty_at kill "$id" >/dev/null 2>&1 || true
    pty_at rm "$id" >/dev/null 2>&1 || true
  done
  cp "$alpha_original" "$alpha_spec" 2>/dev/null || true
  cp "$beta_original" "$beta_spec" 2>/dev/null || true
}
trap cleanup EXIT

invalid="$root/invalid"
mkdir -p "$invalid/agents/ap/empty" "$invalid/workspace"
cat >"$invalid/agents/ap/empty/agent.kdl" <<'KDL'
agent "empty" {
  identity "empty"
  host "ap"
  name ""
  description ""
  workspace "$CATALOG/workspace"
  command "true"
}
KDL
set +e
st2 validate --catalog "$invalid" --host ap --strict >"$root/invalid.out" 2>&1
invalid_rc=$?
set -e
test "$invalid_rc" -ne 0

authoring="$root/authoring"
mkdir -p \
  "$authoring/agents/ap/root" \
  "$authoring/agents/ap/child" \
  "$authoring/agents/ap/grandchild" \
  "$authoring/agents/ap/sibling" \
  "$authoring/agents/ap/nix" \
  "$authoring/agents/ap/json" \
  "$authoring/agents/ap/toml"
cat >"$authoring/agents/ap/root/agent.kdl" <<'KDL'
// preserve-root-comment-b128
agent "root" {
  identity "root"
  host "ap"
  role "fixture"
  meta { managed-by "catalog"; keep "unchanged" }
  command "true"
}
KDL
cat >"$authoring/agents/ap/child/agent.kdl" <<'KDL'
agent "child" {
  identity "child"
  host "ap"
  role "fixture"
  supervisor "ap.root"
  meta { managed-by "catalog" }
  command "true"
}
KDL
cat >"$authoring/agents/ap/grandchild/agent.kdl" <<'KDL'
agent "grandchild" {
  identity "grandchild"
  host "ap"
  role "fixture"
  supervisor "ap.child"
  meta { managed-by "catalog" }
  command "true"
}
KDL
cat >"$authoring/agents/ap/sibling/agent.kdl" <<'KDL'
agent "sibling" {
  identity "sibling"
  host "ap"
  role "fixture"
  supervisor "ap.root"
  meta { managed-by "catalog" }
  command "true"
}
KDL
cat >"$authoring/agents/ap/nix/agent.kdl" <<'KDL'
agent "nix" {
  identity "nix"
  host "ap"
  role "fixture"
  supervisor "ap.root"
  meta { managed-by "nix" }
  command "true"
}
KDL
cat >"$authoring/agents/ap/json/agent.json" <<'JSON'
{"identity":"json","host":"ap","role":"fixture","command":"true"}
JSON
cat >"$authoring/agents/ap/toml/agent.toml" <<'TOML'
identity = "toml"
host = "ap"
role = "fixture"
command = "true"
TOML

env -u ST_AGENT st2 --catalog "$authoring" rename ap.root "Root Operator" --host ap --json \
  | jq -e '. == {result:"changed",identity:"ap.root",field:"name",value:"Root Operator",retired:false}' \
  >/dev/null

name_limit="$(jq -nr '"é" * 160')"
description_limit="$(jq -nr '"é" * 1000')"
for boundary in \
  "rename|$name_limit" \
  "describe|$description_limit"
do
  IFS='|' read -r command value <<<"$boundary"
  env -u ST_AGENT st2 --catalog "$authoring" "$command" ap.root "$value" --host ap --json \
    | jq -e --arg value "$value" '.result == "changed" and .value == $value' >/dev/null
done
st2 validate --catalog "$authoring" --host ap --strict >/dev/null

expect_invalid_presentation() {
  local command="$1"
  local value="$2"
  set +e
  env -u ST_AGENT st2 --catalog "$authoring" "$command" ap.root "$value" --host ap --json \
    >"$root/invalid-presentation.json" 2>"$root/invalid-presentation.err"
  invalid_presentation_rc=$?
  set -e
  test "$invalid_presentation_rc" -ne 0
  jq -e '.result == "error" and .code == "invalid-presentation"' \
    "$root/invalid-presentation.json" >/dev/null
}
expect_invalid_presentation rename "$(jq -nr '"é" * 161')"
expect_invalid_presentation describe "$(jq -nr '"é" * 1001')"
expect_invalid_presentation rename ""
expect_invalid_presentation rename " leading"
expect_invalid_presentation rename "trailing "
expect_invalid_presentation rename $'two\nlines'
expect_invalid_presentation rename $'control\x01character'
expect_invalid_presentation describe ""
expect_invalid_presentation describe " leading"
expect_invalid_presentation describe "trailing "
expect_invalid_presentation describe $'two\nlines'
expect_invalid_presentation describe $'control\x01character'
env -u ST_AGENT st2 --catalog "$authoring" rename ap.root "Root Operator" --host ap --json >/dev/null
env -u ST_AGENT st2 --catalog "$authoring" describe ap.root --clear --host ap --json >/dev/null

ST_AGENT=ap.root st2 --catalog "$authoring" describe ap.child "Owned by root" --host ap --json \
  | jq -e '.result == "changed" and .identity == "ap.child" and .field == "description"' >/dev/null
ST_AGENT=ap.root st2 --catalog "$authoring" describe ap.grandchild "Owned by ancestor" --host ap --json \
  | jq -e '.result == "changed" and .identity == "ap.grandchild" and .field == "description" and .value == "Owned by ancestor"' >/dev/null
grep -Fq 'description "Owned by ancestor"' "$authoring/agents/ap/grandchild/agent.kdl"
ST_AGENT=ap.child st2 --catalog "$authoring" rename ap.child "Child Self" --host ap --json \
  | jq -e '.result == "changed" and .identity == "ap.child" and .field == "name"' >/dev/null
ST_AGENT=ap.child st2 --catalog "$authoring" rename ap.child "Child Self" --host ap --json \
  | jq -e '.result == "unchanged" and .value == "Child Self"' >/dev/null

ST_AGENT=ap.root st2 --catalog "$authoring" rename ap.child "Concurrent Child" --host ap --json \
  >"$root/concurrent-name.json" &
concurrent_name_pid=$!
ST_AGENT=ap.root st2 --catalog "$authoring" describe ap.child "Concurrent description" --host ap --json \
  >"$root/concurrent-description.json" &
concurrent_description_pid=$!
wait "$concurrent_name_pid"
wait "$concurrent_description_pid"
jq -e '.result == "changed" and .field == "name" and .value == "Concurrent Child"' \
  "$root/concurrent-name.json" >/dev/null
jq -e '.result == "changed" and .field == "description" and .value == "Concurrent description"' \
  "$root/concurrent-description.json" >/dev/null
grep -Fq 'name "Concurrent Child"' "$authoring/agents/ap/child/agent.kdl"
grep -Fq 'description "Concurrent description"' "$authoring/agents/ap/child/agent.kdl"
grep -Fq 'supervisor "ap.root"' "$authoring/agents/ap/child/agent.kdl"
grep -Fq 'meta { managed-by "catalog" }' "$authoring/agents/ap/child/agent.kdl"
grep -Fq 'command "true"' "$authoring/agents/ap/child/agent.kdl"

for refusal in \
  'ap.child|rename|ap.sibling|peer denied|presentation-not-authorized' \
  'ap.root|describe|ap.nix|nix denied|nix-managed-declaration' \
  'operator|describe|ap.json|json denied|unsupported-declaration-format' \
  'operator|describe|ap.toml|toml denied|unsupported-declaration-format'
do
  IFS='|' read -r actor command target value code <<<"$refusal"
  if test "$actor" = operator; then
    actor_env=(env -u ST_AGENT)
  else
    actor_env=(env "ST_AGENT=$actor")
  fi
  set +e
  "${actor_env[@]}" st2 --catalog "$authoring" "$command" "$target" "$value" --host ap --json \
    >"$root/$target-$command-refusal.json" 2>"$root/$target-$command-refusal.err"
  refusal_rc=$?
  set -e
  test "$refusal_rc" -ne 0
  jq -e --arg code "$code" '.result == "error" and .code == $code' \
    "$root/$target-$command-refusal.json" >/dev/null
done

ST_AGENT=ap.root st2 --catalog "$authoring" describe ap.child --clear --host ap --json \
  | jq -e '.result == "changed" and .value == null' >/dev/null
env -u ST_AGENT st2 --catalog "$authoring" rename ap.root --clear --host ap --json \
  | jq -e '. == {result:"changed",identity:"ap.root",field:"name",value:null,retired:false}' >/dev/null
! grep -Fq 'name "' "$authoring/agents/ap/root/agent.kdl"
grep -Fqx '// preserve-root-comment-b128' "$authoring/agents/ap/root/agent.kdl"
grep -Fq 'keep "unchanged"' "$authoring/agents/ap/root/agent.kdl"
grep -Fq 'identity "root"' "$authoring/agents/ap/root/agent.kdl"
echo "PRESENTATION-AUTHORING-GREEN-b128"

st2 validate --catalog "$net" --host ap --strict >/dev/null
st2 agents --catalog "$net" --host ap --json >"$root/roster.json"
st2 agents --catalog "$net" --host ap --json >"$root/roster-repeat.json"
cmp "$root/roster.json" "$root/roster-repeat.json"
jq -e '
  [ .[] | select(.identity == "ap.alpha" or .identity == "ap.beta") ] == [
    {
      "identity": "ap.alpha",
      "status": "offline",
      "name": "Shared Worker",
      "description": "Owns alpha acceptance",
      "retired": false,
      "resources": []
    },
    {
      "identity": "ap.beta",
      "status": "offline",
      "name": "Shared Worker",
      "description": "Owns beta acceptance",
      "retired": false,
      "resources": []
    }
  ]
' "$root/roster.json" >/dev/null
echo "PRESENTATION-SCHEMA-GREEN-b128"

st2 up --once --catalog "$net" --host ap >"$root/launch.out"
wait_running ap.alpha
wait_running ap.alpha.helper
wait_running ap.beta
alpha_before="$(generation ap.alpha)"
alpha_helper_before="$(generation ap.alpha.helper)"
alpha_helper_display="$(session ap.alpha.helper | jq -c '.displayName // null')"
beta_before="$(generation ap.beta)"
test "$(event_count ap.alpha session_start)" -eq 1
test "$(event_count ap.alpha.helper session_start)" -eq 1
test "$(event_count ap.beta session_start)" -eq 1
test "$(session ap.alpha | jq -r '.displayName')" = "Shared Worker"
test "$(session ap.beta | jq -r '.displayName')" = "Shared Worker"
test "$(session ap.alpha.helper | jq -r '.displayName // "absent"')" != "Shared Worker"
jq -e '
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.alpha" and
  .tags["agent.presentation.description"] == "Owns alpha acceptance" and
  (.tags | has("agent.presentation.name") | not)
' <<<"$(session ap.alpha)" >/dev/null
jq -e '
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.beta" and
  .tags["agent.presentation.description"] == "Owns beta acceptance" and
  (.tags | has("agent.presentation.name") | not)
' <<<"$(session ap.beta)" >/dev/null
jq -e '
  .tags["purpose"] == "secondary" and
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.alpha" and
  .tags["agent.presentation.description"] == "Owns alpha acceptance" and
  (.tags | has("agent.presentation.name") | not)
' <<<"$(session ap.alpha.helper)" >/dev/null

set +e
pty_at peek --plain "Shared Worker" >"$root/ambiguous.out" 2>"$root/ambiguous.err"
ambiguous_rc=$?
set -e
test "$ambiguous_rc" -ne 0
grep -Fq ap.alpha "$root/ambiguous.err"
grep -Fq ap.beta "$root/ambiguous.err"
test "$(grep -o 'ap\.alpha\|ap\.beta' "$root/ambiguous.err" | paste -sd, -)" = ap.alpha,ap.beta
pty_at peek --plain ap.alpha | grep -Fq alpha-GENERATION-1-b128
echo "PRESENTATION-DUPLICATES-GREEN-b128"

st2 message send ap.alpha --catalog "$net" --host ap --as ap.sender \
  --subject STABLE-ID-ROUTING-b128 >/dev/null <<'MSG'
STABLE-ID-BODY-b128
MSG
grep -Fq STABLE-ID-BODY-b128 "$net/agents/ap/alpha/resources/inbox/"*.md
set +e
st2 message send "Shared Worker" --catalog "$net" --host ap --as ap.sender \
  --subject DISPLAY-MUST-NOT-ROUTE-b128 \
  >"$root/display-route.out" 2>"$root/display-route.err" <<'MSG'
DISPLAY-MUST-NOT-ROUTE-b128
MSG
display_route_rc=$?
st2 status "Shared Worker" --set busy --catalog "$net" --host ap --as ap.sender \
  >"$root/display-status.out" 2>"$root/display-status.err"
display_status_rc=$?
st2 message send "Owns alpha acceptance" --catalog "$net" --host ap --as ap.sender \
  --subject DESCRIPTION-MUST-NOT-ROUTE-b128 \
  >"$root/description-route.out" 2>"$root/description-route.err" <<'MSG'
DESCRIPTION-MUST-NOT-ROUTE-b128
MSG
description_route_rc=$?
set -e
test "$display_route_rc" -ne 0
test "$display_status_rc" -ne 0
test "$description_route_rc" -ne 0
! grep -RFq DISPLAY-MUST-NOT-ROUTE-b128 "$net/agents/ap"
! grep -RFq DESCRIPTION-MUST-NOT-ROUTE-b128 "$net"
echo "PRESENTATION-ROUTING-GREEN-b128"

pty_at tag ap.alpha external.keep=untouched >/dev/null
alpha_metadata_events="$(event_count ap.alpha metadata_change)"
alpha_display_events="$(event_count ap.alpha display_name_change)"
alpha_tag_events="$(event_count ap.alpha tags_change)"
sed -i 's/name "Shared Worker"/name "ap.beta"/' "$alpha_spec"
st2 up --once --catalog "$net" --host ap >"$root/id-collision.out"
test "$(generation ap.alpha)" = "$alpha_before"
test "$(generation ap.alpha.helper)" = "$alpha_helper_before"
test "$(generation ap.beta)" = "$beta_before"
test "$(session ap.alpha | jq -r '.displayName')" = ap.beta
test "$(session ap.alpha.helper | jq -c '.displayName // null')" = "$alpha_helper_display"
jq -e '
  .tags["external.keep"] == "untouched" and
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.alpha" and
  .tags["agent.presentation.description"] == "Owns alpha acceptance"
' <<<"$(session ap.alpha)" >/dev/null
test "$(event_count ap.alpha metadata_change)" -eq $((alpha_metadata_events + 1))
test "$(event_count ap.alpha display_name_change)" -eq "$alpha_display_events"
test "$(event_count ap.alpha tags_change)" -eq "$alpha_tag_events"
jq -e '
  .previous == {displayName:"Shared Worker"} and
  .value == {displayName:"ap.beta"}
' <<<"$(last_metadata_event ap.alpha)" >/dev/null
pty_at peek --plain ap.beta | grep -Fq beta-GENERATION-1-b128

sed -i 's/name "ap.beta"/name "Alpha Renamed"/' "$alpha_spec"
sed -i 's/description "Owns alpha acceptance"/description "Owns renamed alpha acceptance"/' "$alpha_spec"
old_projection="$(presentation ap.alpha)"
rm -f "$root/change.done"
(
  while ! test -f "$root/change.done"; do
    presentation ap.alpha >>"$root/change-observations.jsonl"
  done
) &
observer_pid=$!
st2 up --once --catalog "$net" --host ap >"$root/change.out"
touch "$root/change.done"
wait "$observer_pid"
test "$(generation ap.alpha)" = "$alpha_before"
test "$(generation ap.alpha.helper)" = "$alpha_helper_before"
test "$(generation ap.beta)" = "$beta_before"
test "$(event_count ap.alpha session_start)" -eq 1
test "$(session ap.alpha | jq -r '.displayName')" = "Alpha Renamed"
new_projection="$(presentation ap.alpha)"
jq -s -e --argjson old "$old_projection" --argjson new "$new_projection" \
  'length > 0 and all(. == $old or . == $new)' "$root/change-observations.jsonl" >/dev/null
jq -e '
  .tags["external.keep"] == "untouched" and
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.alpha" and
  .tags["agent.presentation.description"] == "Owns renamed alpha acceptance" and
  (.tags | has("agent.presentation.name") | not)
' <<<"$(session ap.alpha)" >/dev/null
jq -e '
  .tags["purpose"] == "secondary" and
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.alpha" and
  .tags["agent.presentation.description"] == "Owns renamed alpha acceptance"
' <<<"$(session ap.alpha.helper)" >/dev/null
test "$(session ap.alpha.helper | jq -c '.displayName // null')" = "$alpha_helper_display"
test "$(event_count ap.alpha metadata_change)" -eq $((alpha_metadata_events + 2))
test "$(event_count ap.alpha display_name_change)" -eq "$alpha_display_events"
test "$(event_count ap.alpha tags_change)" -eq "$alpha_tag_events"
jq -e '
  .previous == {
    displayName:"ap.beta",
    tags:{"agent.presentation.description":"Owns alpha acceptance"}
  } and
  .value == {
    displayName:"Alpha Renamed",
    tags:{"agent.presentation.description":"Owns renamed alpha acceptance"}
  }
' <<<"$(last_metadata_event ap.alpha)" >/dev/null

changed_events="$(wc -l <"$PTY_ROOT/ap.alpha.events.jsonl")"
st2 up --once --catalog "$net" --host ap >"$root/idempotent.out"
test "$(generation ap.alpha)" = "$alpha_before"
test "$(wc -l <"$PTY_ROOT/ap.alpha.events.jsonl")" -eq "$changed_events"
echo "PRESENTATION-IDEMPOTENCE-GREEN-b128"

sed -i '/^  name "/d;/^  description "/d' "$alpha_spec"
st2 up --once --catalog "$net" --host ap >"$root/clear.out"
test "$(generation ap.alpha)" = "$alpha_before"
test "$(generation ap.alpha.helper)" = "$alpha_helper_before"
test "$(session ap.alpha | jq -r '.displayName // "absent"')" = absent
test "$(event_count ap.alpha metadata_change)" -eq $((alpha_metadata_events + 3))
test "$(event_count ap.alpha display_name_change)" -eq "$alpha_display_events"
test "$(event_count ap.alpha tags_change)" -eq "$alpha_tag_events"
jq -e '
  .previous == {
    displayName:"Alpha Renamed",
    tags:{"agent.presentation.description":"Owns renamed alpha acceptance"}
  } and
  .value == {
    displayName:null,
    tags:{"agent.presentation.description":null}
  }
' <<<"$(last_metadata_event ap.alpha)" >/dev/null
jq -e '
  .tags["external.keep"] == "untouched" and
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.alpha" and
  (.tags | has("agent.presentation.description") | not) and
  (.tags | has("agent.presentation.name") | not)
' <<<"$(session ap.alpha)" >/dev/null
jq -e '
  .tags["purpose"] == "secondary" and
  .tags["agent.presentation.schema"] == "1" and
  .tags["agent.actor.path"] == "ap.alpha" and
  (.tags | has("agent.presentation.description") | not)
' <<<"$(session ap.alpha.helper)" >/dev/null
test "$(session ap.alpha.helper | jq -c '.displayName // null')" = "$alpha_helper_display"
st2 agents --catalog "$net" --host ap --json >"$root/cleared-roster.json"
jq -e '.[] | select(.identity == "ap.alpha") | .name == null and .description == null' \
  "$root/cleared-roster.json" >/dev/null
echo "PRESENTATION-PROJECTION-GREEN-b128"

pty_at kill ap.alpha >/dev/null
test "$(session ap.alpha | jq -r '.status')" != running
st2 up --once --catalog "$net" --host ap >"$root/lifecycle.out"
wait_running ap.alpha
grep -Fq 'restarted (1): ap.alpha' "$root/lifecycle.out"
test "$(cat "$net/alpha-count")" -eq 2
test "$(generation ap.alpha)" != "$alpha_before"
test "$(event_count ap.alpha session_start)" -eq 1
test "$(generation ap.alpha.helper)" = "$alpha_helper_before"
test "$(generation ap.beta)" = "$beta_before"
echo "PRESENTATION-LIFECYCLE-CONTROL-GREEN-b128"

retire "$alpha_spec"
retire "$beta_spec"
st2 up --once --catalog "$net" --host ap >/dev/null
for id in ap.alpha ap.alpha.helper ap.beta; do
  pty_at rm "$id" >/dev/null 2>&1 || true
done
cp "$alpha_original" "$alpha_spec"
cp "$beta_original" "$beta_spec"
trap - EXIT
test "$(pty_at list --json | jq 'length')" -eq 0
echo "PRESENTATION-CLEANUP-GREEN-b128"
