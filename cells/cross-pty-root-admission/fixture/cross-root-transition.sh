#!/usr/bin/env bash
set -euo pipefail

: "${CATALOG:?CATALOG must be set}"
base="$(mktemp -d /tmp/st2-eval-cross-root.XXXXXX)"
host="evalhost"

pty_rows() {
  root="$1"
  bus_id="$2"
  PTY_ROOT="$root" pty list --json |
    jq -c --arg id "$bus_id" \
      '[.[] | select(.name == $id and .status == "running") | {name,status,pid}]'
}

cleanup_root() {
  root="$1"
  bus_id="$2"
  PTY_ROOT="$root" pty kill "$bus_id" >/dev/null 2>&1 || true
  for _ in $(seq 1 50); do
    if test "$(pty_rows "$root" "$bus_id" | jq 'length')" -eq 0; then
      break
    fi
    sleep 0.1
  done
  PTY_ROOT="$root" pty rm "$bus_id" >/dev/null 2>&1 || true
}

cleanup_sessions() {
  cleanup_root "$base/control/pty-a" "$host.control"
  cleanup_root "$base/control/pty-b" "$host.control"
  cleanup_root "$base/a-to-b/pty-a" "$host.forward"
  cleanup_root "$base/a-to-b/pty-b" "$host.forward"
  cleanup_root "$base/b-to-a/pty-a" "$host.reverse"
  cleanup_root "$base/b-to-a/pty-b" "$host.reverse"
  cleanup_root "$base/sibling-prefix/pty-a" "$host.sibling"
  cleanup_root "$base/sibling-prefix/pty-b" "$host.sibling"
  cleanup_root "$base/sibling-prefix/pty-a" "$host.sibling.child"
  cleanup_root "$base/sibling-prefix/pty-b" "$host.sibling.child"
}

remove_base() {
  case "$base" in
    /tmp/st2-eval-cross-root.*) rm -rf -- "$base" ;;
    *) printf 'refusing to remove unexpected fixture path: %s\n' "$base" >&2 ;;
  esac
}

cleanup() {
  cleanup_sessions || true
  remove_base
}
trap cleanup EXIT INT TERM

make_catalog() {
  scenario="$1"
  identity="$2"
  declared_root="$3"
  catalog="$base/$scenario/catalog"
  workspace="$base/$scenario/workspace"

  mkdir -p \
    "$catalog/agents/$host/$identity" \
    "$base/$scenario/pty-a" \
    "$base/$scenario/pty-b" \
    "$base/$scenario/xdg-state" \
    "$workspace"

  printf 'catalog {\n  pty-root "%s"\n}\n' "$declared_root" >"$catalog/catalog.kdl"
  printf 'agent "%s" {\n  identity "%s"\n  host "%s"\n  workspace "%s"\n  command "exec sleep 300"\n}\n' \
    "$identity" "$identity" "$host" "$workspace" \
    >"$catalog/agents/$host/$identity/agent.kdl"

  env -u PTY_ROOT -u PTY_SESSION_DIR \
    XDG_STATE_HOME="$base/$scenario/xdg-state" \
    st2 validate --catalog "$catalog" --host "$host" --strict >/dev/null
}

reconcile_with_root() {
  scenario="$1"
  root="$2"
  env -u PTY_SESSION_DIR \
    PTY_ROOT="$root" \
    XDG_STATE_HOME="$base/$scenario/xdg-state" \
    st2 up --catalog "$base/$scenario/catalog" --host "$host" --once
}

reconcile_declared_root() {
  scenario="$1"
  env -u PTY_ROOT -u PTY_SESSION_DIR \
    XDG_STATE_HOME="$base/$scenario/xdg-state" \
    st2 up --catalog "$base/$scenario/catalog" --host "$host" --once
}

run_same_root_control() {
  scenario="control"
  identity="control"
  bus_id="$host.$identity"
  root_a="$base/$scenario/pty-a"
  root_b="$base/$scenario/pty-b"

  make_catalog "$scenario" "$identity" "$root_a"
  reconcile_with_root "$scenario" "$root_a" >/dev/null
  before_a="$(pty_rows "$root_a" "$bus_id")"
  reconcile_with_root "$scenario" "$root_a" >/dev/null
  after_a="$(pty_rows "$root_a" "$bus_id")"
  after_b="$(pty_rows "$root_b" "$bus_id")"

  test "$(jq 'length' <<<"$before_a")" -eq 1
  test "$(jq 'length' <<<"$after_a")" -eq 1
  test "$(jq 'length' <<<"$after_b")" -eq 0
  test "$(jq -r '.[0].pid' <<<"$before_a")" = "$(jq -r '.[0].pid' <<<"$after_a")"
  echo "SAME-ROOT-ADOPTED-GREEN-7d31"

  cleanup_root "$root_a" "$bus_id"
}

run_transition() {
  scenario="$1"
  identity="$2"
  source_root="$3"
  destination_root="$4"
  marker="$5"
  bus_id="$host.$identity"

  make_catalog "$scenario" "$identity" "$destination_root"
  reconcile_with_root "$scenario" "$source_root" >/dev/null
  source_before="$(pty_rows "$source_root" "$bus_id")"
  destination_before="$(pty_rows "$destination_root" "$bus_id")"
  test "$(jq 'length' <<<"$source_before")" -eq 1
  test "$(jq 'length' <<<"$destination_before")" -eq 0

  set +e
  reconcile_declared_root "$scenario" >"$base/$scenario/reconcile.out" 2>"$base/$scenario/reconcile.err"
  reconcile_status=$?
  set -e

  source_after="$(pty_rows "$source_root" "$bus_id")"
  destination_after="$(pty_rows "$destination_root" "$bus_id")"
  source_count="$(jq 'length' <<<"$source_after")"
  destination_count="$(jq 'length' <<<"$destination_after")"
  total_count=$((source_count + destination_count))

  printf '%s-RECONCILE-EXIT-%s\n' "$marker" "$reconcile_status"
  printf '%s-SOURCE=%s\n' "$marker" "$source_after"
  printf '%s-DESTINATION=%s\n' "$marker" "$destination_after"

  transition_safe=0
  if test "$total_count" -eq 1; then
    printf '%s-SINGLE-LIVE-GREEN-7d31\n' "$marker"
    transition_safe=1
  else
    printf '%s-DUPLICATE-RED-7d31\n' "$marker"
  fi

  cleanup_root "$source_root" "$bus_id"
  reconcile_declared_root "$scenario" >/dev/null
  test "$(pty_rows "$source_root" "$bus_id" | jq 'length')" -eq 0
  test "$(pty_rows "$destination_root" "$bus_id" | jq 'length')" -eq 1
  printf '%s-ADVANCE-GREEN-7d31\n' "$marker"
  cleanup_root "$destination_root" "$bus_id"

  test "$transition_safe" -eq 1
}

run_sibling_prefix_control() {
  scenario="sibling-prefix"
  identity="sibling"
  bus_id="$host.$identity"
  sibling_id="$bus_id.child"
  root_a="$base/$scenario/pty-a"
  root_b="$base/$scenario/pty-b"

  make_catalog "$scenario" "$identity" "$root_b"
  reconcile_with_root "$scenario" "$root_a" >/dev/null
  cleanup_root "$root_a" "$bus_id"
  PTY_ROOT="$root_a" pty run -d --id "$sibling_id" -- sleep 300 >/dev/null

  reconcile_declared_root "$scenario" >/dev/null
  test "$(pty_rows "$root_a" "$bus_id" | jq 'length')" -eq 0
  test "$(pty_rows "$root_b" "$bus_id" | jq 'length')" -eq 1
  test "$(pty_rows "$root_a" "$sibling_id" | jq 'length')" -eq 1
  echo "SIBLING-PREFIX-NONBLOCKING-GREEN-7d31"

  cleanup_root "$root_a" "$sibling_id"
  cleanup_root "$root_b" "$bus_id"
}

mkdir -p "$base"
printf 'st2=%s\n' "$(st2 --version)"
printf 'pty=%s\n' "$(pty --version)"

run_same_root_control

transition_failures=0
run_transition \
  "a-to-b" \
  "forward" \
  "$base/a-to-b/pty-a" \
  "$base/a-to-b/pty-b" \
  "A-TO-B" ||
  transition_failures=$((transition_failures + 1))
run_transition \
  "b-to-a" \
  "reverse" \
  "$base/b-to-a/pty-b" \
  "$base/b-to-a/pty-a" \
  "B-TO-A" ||
  transition_failures=$((transition_failures + 1))
run_sibling_prefix_control

if test "$transition_failures" -eq 0; then
  echo "TRANSITION-SURVIVAL-GREEN-7d31"
else
  echo "TRANSITION-DUPLICATION-RED-7d31"
fi

cleanup_sessions

for scenario in control a-to-b b-to-a sibling-prefix; do
  for root in pty-a pty-b; do
    test "$(PTY_ROOT="$base/$scenario/$root" pty list --json | jq '[.[] | select(.status == "running")] | length')" -eq 0
  done
done
echo "CROSS-ROOT-CLEANUP-GREEN-7d31"
remove_base
trap - EXIT INT TERM
