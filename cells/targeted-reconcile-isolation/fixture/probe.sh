#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}/targeted-reconcile-isolation"
shim_bin="$root/bin"
mkdir -p "$shim_bin"

cat >"$shim_bin/pty" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${PTY_CALLS:?PTY_CALLS must be set}"
if [ "${1:-}" = "list" ] && [ "${2:-}" = "--json" ]; then
  printf '[]\n'
  exit 0
fi
exit 97
SH
chmod +x "$shim_bin/pty"
probe_path="$shim_bin:$PATH"

write_catalog() {
  case_root="$1"
  for identity in one two; do
    workspace="$case_root/workspaces/$identity"
    declaration="$case_root/catalog/agents/repro/$identity/agent.kdl"
    mkdir -p "$workspace" "$(dirname "$declaration")"
    cat >"$declaration" <<KDL
agent "$identity" {
  host "repro"
  type "service"
  workspace "$workspace"
  exec "work" {
    id "repro.$identity.work"
    command "true"
  }
  render {
    file "MATERIALIZED" "$identity"
  }
}
KDL
  done
}

run_st2() {
  case_root="$1"
  shift
  PATH="$probe_path" \
    PTY_CALLS="$case_root/pty-calls" \
    PTY_ROOT="$case_root/pty" \
    XDG_STATE_HOME="$case_root/xdg" \
    st2 up --catalog "$case_root/catalog" --host repro "$@"
}

st2 up --help | grep -Fq -- '--task <TASK>'
echo "TASK-SELECTOR-SURFACE-GREEN-4f2d"

refusal="$root/refusal"
write_catalog "$refusal"
set +e
run_st2 "$refusal" --once --agent one >"$refusal/stdout" 2>"$refusal/stderr"
refusal_rc=$?
set -e
test "$refusal_rc" -ne 0
grep -Fq -- '--agent requires --materialize-only' "$refusal/stderr"
test ! -e "$refusal/pty-calls"
echo "LEGACY-ONCE-AGENT-REFUSAL-GREEN-4f2d"
test ! -e "$refusal/workspaces/one/MATERIALIZED"
test ! -e "$refusal/workspaces/two/MATERIALIZED"
echo "LEGACY-REFUSAL-NO-MUTATION-GREEN-4f2d"

materialize="$root/materialize"
write_catalog "$materialize"
run_st2 "$materialize" --materialize-only --agent one \
  >"$materialize/stdout" 2>"$materialize/stderr"
test "$(cat "$materialize/workspaces/one/MATERIALIZED")" = "one"
test ! -e "$materialize/workspaces/two/MATERIALIZED"
test ! -e "$materialize/pty-calls"
echo "AGENT-MATERIALIZE-ONLY-GREEN-4f2d"

targeted="$root/targeted"
write_catalog "$targeted"
run_st2 "$targeted" --once --task repro.one.work \
  >"$targeted/stdout" 2>"$targeted/stderr"
grep -Fq 'launched (1): repro.one.work' "$targeted/stdout"
test "$(cat "$targeted/workspaces/one/MATERIALIZED")" = "one"
test "$(cat "$targeted/pty-calls")" = "list --json"
echo "TARGETED-OWNER-ONLY-GREEN-4f2d"
test ! -e "$targeted/workspaces/two/MATERIALIZED"
! grep -Fq 'repro.two.work' "$targeted/stdout"
echo "TARGETED-SIBLING-ISOLATION-GREEN-4f2d"

control="$root/control"
write_catalog "$control"
run_st2 "$control" --once >"$control/stdout" 2>"$control/stderr"
grep -Fq 'repro.one.work' "$control/stdout"
grep -Fq 'repro.two.work' "$control/stdout"
test "$(cat "$control/workspaces/one/MATERIALIZED")" = "one"
test "$(cat "$control/workspaces/two/MATERIALIZED")" = "two"
test "$(cat "$control/pty-calls")" = "list --json"
echo "WHOLE-CATALOG-CONTROL-GREEN-4f2d"
