#!/usr/bin/env bash
# pi native-delivery contract probe.
#
# Every assertion here is deterministic: no model seat, no pi binary, no network. Each section
# prints its sentinel only on success, and the judges grep for exact sentinels — so a section that
# dies early fails its judge rather than silently passing.
set -uo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ---------------------------------------------------------------------------------------------
# EXPANSION
#
# The declaration must not name the channel extension: `st2 driver pi-session` splices it in from
# the binary's verified hook set, so a catalog never carries a machine-local path. `-a` must be
# present, because pi's project-trust modal otherwise blocks startup before any event fires.
# ---------------------------------------------------------------------------------------------
expansion_catalog="$work/expansion"
mkdir -p "$expansion_catalog/agents/evalhost/pilot"
cat > "$expansion_catalog/agents/evalhost/pilot/agent.kdl" <<'KDL'
agent "pilot" {
  host "evalhost"
  workspace "/tmp/pi-eval-ws"
  pi {
    model "provider/model"
    effort "medium"
    prompt "Start the assigned work."
  }
}
KDL

expanded="$(st2 --catalog "$expansion_catalog" driver expand \
  "$expansion_catalog/agents/evalhost/pilot/agent.kdl" 2>&1)" ||
  fail "driver expand failed: $expanded"

case "$expanded" in
  *"driver pi-session"*) ;;
  *) fail "expansion does not route through the pi-session wrapper: $expanded" ;;
esac
case "$expanded" in
  *"-- pi -a "*) ;;
  *) fail "expansion does not accept the workspace with -a: $expanded" ;;
esac
case "$expanded" in
  *pi-channel.ts*) fail "expansion leaked the channel extension path into the declaration" ;;
  *ST_HOOKS*) fail "expansion leaked an \$ST_HOOKS token into an argv" ;;
  *) ;;
esac
case "$expanded" in
  *"--thinking medium"*) ;;
  *) fail "effort did not lower to pi's thinking level: $expanded" ;;
esac
printf 'PI-EXPANSION-GREEN-p1a7\n'

# ---------------------------------------------------------------------------------------------
# EXCLUSIVITY
#
# This is the rule that keeps a natively-delivered seat off the PTY write path entirely, which is
# what leaves decision 0004's synchronous-proof gate untouched. It must fail closed at validation.
# ---------------------------------------------------------------------------------------------
both_catalog="$work/both"
mkdir -p "$both_catalog/agents/evalhost/pilot"
cat > "$both_catalog/agents/evalhost/pilot/agent.kdl" <<'KDL'
agent "pilot" {
  host "evalhost"
  workspace "/tmp/pi-eval-ws"
  command "pi"
  ding
  deliver "pi-channel"
}
KDL

if both_out="$(st2 validate --catalog "$both_catalog" 2>&1)"; then
  fail "a declaration carrying both ding and deliver was accepted: $both_out"
fi
case "$both_out" in
  *"choose one transport"*) ;;
  *) fail "refusal did not name the transport conflict: $both_out" ;;
esac
printf 'PI-EXCLUSIVITY-GREEN-p1a7\n'

# ---------------------------------------------------------------------------------------------
# TRANSPORT
#
# The hand-authored `deliver "pi-channel"` form must reach the SAME wrapper as the typed pi driver,
# and must add no DING companion.
#
# Asserting only "the JSON has no ding and mentions pilot" would be vacuous for a judge whose stated
# purpose is the wrapper: a declaration compiled to the wrong wrapper entirely would still pass it.
# The task inventory does not expose argv, so the two paths are compiled for real and their launched
# command lines compared. Byte equality after normalising the catalog path is what proves
# convergence — strictly stronger than matching a wrapper substring, because it also catches a
# divergent identity, runtime id, or provider argv.
#
# Still model-free: `pi` here is a stub that sleeps, and nothing contacts a model or the network.
# ---------------------------------------------------------------------------------------------
transport_bin="$work/bin"
mkdir -p "$transport_bin"
printf '#!/usr/bin/env bash\nsleep 30\n' > "$transport_bin/pi"
chmod +x "$transport_bin/pi"

transport_hooks="$work/transport-hooks"
mkdir -p "$transport_hooks"
ST_HOOKS="$transport_hooks" st2 hooks install >/dev/null 2>&1 ||
  fail "hooks install failed while preparing the transport comparison"

compile_launch() {
  # Launch one variant in its own PTY root and echo its command line with the catalog path masked.
  # A separate root per variant is required: both variants resolve to the same session id, so a
  # shared root would make the second pass adopt the first instead of compiling its own launch.
  local variant="$1" catalog="$2"
  local root="$work/pty-$variant"
  mkdir -p "$root"
  PATH="$transport_bin:$PATH" ST_HOOKS="$transport_hooks" PTY_ROOT="$root" \
    st2 up --catalog "$catalog" --host evalhost --once >/dev/null 2>&1
  sleep 2
  local command
  command="$(PTY_ROOT="$root" pty list --json 2>/dev/null |
    python3 -c "import json,sys;print(next((s['command'] for s in json.load(sys.stdin)),'ABSENT'))")"
  PTY_ROOT="$root" ST_HOOKS="$transport_hooks" \
    st2 down --catalog "$catalog" --host evalhost >/dev/null 2>&1
  printf '%s' "${command//$catalog/<CATALOG>}"
}

typed_catalog="$work/typed"
mkdir -p "$typed_catalog/agents/evalhost/pilot" "$work/ws-typed"
cat > "$typed_catalog/agents/evalhost/pilot/agent.kdl" <<KDL
agent "pilot" {
  host "evalhost"
  workspace "$work/ws-typed"
  pi {
    model "provider/model"
    prompt "boot"
  }
}
KDL

deliver_catalog="$work/deliver"
mkdir -p "$deliver_catalog/agents/evalhost/pilot" "$work/ws-deliver"
cat > "$deliver_catalog/agents/evalhost/pilot/agent.kdl" <<KDL
agent "pilot" {
  host "evalhost"
  workspace "$work/ws-deliver"
  deliver "pi-channel"
  argv "pi" "-a" "--model" "provider/model" "boot"
}
KDL

typed_argv="$(compile_launch typed "$typed_catalog")"
deliver_argv="$(compile_launch deliver "$deliver_catalog")"

# Non-vacuous: a variant that never launched must fail rather than compare equal as "ABSENT".
[ "$typed_argv" != "ABSENT" ] || fail "the typed pi driver produced no launch to compare"
[ "$deliver_argv" != "ABSENT" ] || fail "deliver \"pi-channel\" produced no launch to compare"

case "$typed_argv" in
  *"driver pi-session"*) ;;
  *) fail "the typed pi driver did not compile to the pi-session wrapper: $typed_argv" ;;
esac
case "$deliver_argv" in
  *"driver pi-session"*) ;;
  *) fail "deliver \"pi-channel\" did not compile to the pi-session wrapper: $deliver_argv" ;;
esac
case "$deliver_argv" in
  *"-- pi -a --model provider/model boot"*) ;;
  *) fail "the authored provider argv did not survive wrapping: $deliver_argv" ;;
esac
[ "$typed_argv" = "$deliver_argv" ] ||
  fail "the two declaration paths diverge:
  typed:   $typed_argv
  deliver: $deliver_argv"

# No DING companion for a natively-delivered seat: a companion would mean the seat was also being
# poked through the terminal, which is exactly what `deliver` exists to avoid.
tasks="$(st2 tasks --catalog "$deliver_catalog" --host evalhost --json 2>&1)" ||
  fail "task inventory failed for a deliver \"pi-channel\" declaration: $tasks"
case "$tasks" in
  *'"ding"'*) fail "a DING companion was generated for a natively-delivered seat: $tasks" ;;
  *) ;;
esac
case "$tasks" in
  *pilot*) ;;
  *) fail "the pi seat is absent from the inventory: $tasks" ;;
esac
printf 'PI-TRANSPORT-GREEN-p1a7\n'

# ---------------------------------------------------------------------------------------------
# HOOKSET
#
# pi has no hook mechanism of its own, so its channel extension ships in the same immutable set as
# the Codex and Claude lifecycle scripts and is content-addressed with them.
# ---------------------------------------------------------------------------------------------
hooks_root="$work/hooks"
mkdir -p "$hooks_root"
ST_HOOKS="$hooks_root" st2 hooks install >/dev/null 2>&1 ||
  fail "hooks install failed"
selected="$(ST_HOOKS="$hooks_root" st2 hooks verify 2>&1)" ||
  fail "hooks verify failed: $selected"
find "$hooks_root" -name pi-channel.ts -print -quit | grep -q . ||
  fail "the installed hook set does not contain pi-channel.ts"
printf 'PI-HOOKSET-GREEN-p1a7\n'

# ---------------------------------------------------------------------------------------------
# FAIL-CLOSED
#
# Without a verified set the wrapper cannot supply the channel, so the launch must be HELD and the
# error must name the remedy. A flapping task would bury that message in a restart loop.
# ---------------------------------------------------------------------------------------------
empty_hooks="$work/hooks-empty"
mkdir -p "$empty_hooks"
gate_out="$(ST_HOOKS="$empty_hooks" st2 up --catalog "$deliver_catalog" --host evalhost --once 2>&1)"
case "$gate_out" in
  *"hooks"*) ;;
  *) fail "an unverified hook set did not surface a hook error: $gate_out" ;;
esac
case "$gate_out" in
  *"launch suppressed"*|*"materialization deferred"*) ;;
  *) fail "the launch was not held on an unverified set: $gate_out" ;;
esac
printf 'PI-GATE-GREEN-p1a7\n'

# ---------------------------------------------------------------------------------------------
# CONTRACT
#
# The restored boot ritual is a pointer into the shipped bus contract, not a standalone
# instruction. The maintained example must therefore put that contract where pi reads it, verbatim.
# ---------------------------------------------------------------------------------------------
contract_src="./contract-asset.md"
[ -f "$contract_src" ] || fail "the fixture is missing its contract asset"

render_catalog="$work/render"
mkdir -p "$render_catalog/agents/evalhost/pilot/assets" "$work/render-ws"
cp "$contract_src" "$render_catalog/agents/evalhost/pilot/assets/bus.st2.md"
cat > "$render_catalog/agents/evalhost/pilot/agent.kdl" <<KDL
agent "pilot" {
  host "evalhost"
  workspace "$work/render-ws"
  pi {
    model "provider/model"
    prompt "Start the assigned work."
  }
  render {
    copy "assets/bus.st2.md" "AGENTS.md"
    git-exclude "AGENTS.md"
  }
}
KDL

render_out="$(st2 up --catalog "$render_catalog" --host evalhost --materialize-only 2>&1)" ||
  fail "materialization failed: $render_out"
cmp -s "$contract_src" "$work/render-ws/AGENTS.md" ||
  fail "the rendered contract asset is not byte-identical to the declared source"
grep -Fq 'st2 status $ST_AGENT --set available' "$work/render-ws/AGENTS.md" ||
  fail "the rendered contract does not name the status command the ritual points at"
printf 'PI-BUS-CONTRACT-GREEN-p1a7\n'
