#!/usr/bin/env bash
# Launch si-agent via REAL convoy (convoy add, ding-default) on the ISOLATED net ($ST_ROOT), then make its
# claude session load the PLUGIN scope by adding `--plugin-dir <sandbox>/plugin/evalpkg` to the launch
# command. convoy add does not pass claude flags through, so we edit the [sessions.claude] command in the
# repo pty.toml convoy wrote, then RE-LAUNCH just the claude session from that edited toml:
#     pty down <repo> claude   →   pty gc (release the name)   →   pty up <repo> claude
# `pty up` reads the toml file fresh (unlike `pty restart`, which respawns from cached daemon state and would
# drop the edit) and needs no TTY (unlike attach/`pty restart` from inside a pty session). The ding sidecar
# is left running throughout. PROJECT scope needs no injection: it auto-loads from <repo>/.claude/skills via
# --dir. Hard-fails if --plugin-dir does not land, so a broken plugin leg can't pass silently.
#   ./configure-claude-agent.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/skill-inheritance}"
NET="${ST_ROOT:?configure: export ST_ROOT (spin.sh does)}"
REPO="$SB/repo"; PR="$NET/pty"
PLUGIN_DIR="$SB/plugin/evalpkg"
SESS="silber.si-agent-claude"
[ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ] || { echo "configure: missing plugin at $PLUGIN_DIR — run setup-sandbox.sh first" >&2; exit 1; }

# 1) convoy add (writes $REPO/pty.toml + starts claude+ding, WITHOUT --plugin-dir yet)
stev_convoy_add "si-agent" "$REPO" "auto" "$SB/personas-local/si-agent.md"

# 2) add --plugin-dir to the [sessions.claude] command line in the repo pty.toml (idempotent)
python3 - "$REPO/pty.toml" "$PLUGIN_DIR" <<'PY'
import sys
toml, plugdir = sys.argv[1], sys.argv[2]
inject = "exec claude --plugin-dir '%s' " % plugdir
lines = open(toml).read().splitlines(keepends=True)
done = False
for i, ln in enumerate(lines):
    if ln.lstrip().startswith("command =") and "exec claude " in ln and "--plugin-dir" not in ln:
        lines[i] = ln.replace("exec claude ", inject, 1); done = True; break
open(toml, "w").write("".join(lines))
print("edited pty.toml [sessions.claude] with --plugin-dir" if done else "pty.toml already had --plugin-dir")
PY

# 3) re-launch ONLY the claude session from the edited toml (leave ding + inbox untouched).
# `pty up` refuses to recreate an id that's still registered, so after stopping the session we remove ONLY
# its registry files (the ding sidecar's files and $NET/si-agent/inbox are separate) to free the name
# deterministically — no reliance on gc timing. Then `pty up` reads the edited toml fresh.
echo "re-launching si-agent's claude session from the edited pty.toml (adds --plugin-dir)"
pty --root "$PR" down "$REPO" claude >/dev/null 2>&1 || true
pty --root "$PR" kill "$SESS" >/dev/null 2>&1 || true
sleep 1
rm -f "$PR/silber.si-agent.json" "$PR/silber.si-agent.pid" "$PR/silber.si-agent.events.jsonl" "$PR/silber.si-agent.sock"
pty --root "$PR" up "$REPO" claude 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -2

# 4) hard self-check: --plugin-dir MUST be on the running command, else the plugin leg is silently broken
sleep 2
if pty --root "$PR" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep "$SESS" | grep -q -- "--plugin-dir '$PLUGIN_DIR'"; then
  echo "si-agent up with PLUGIN scope injected (--plugin-dir $PLUGIN_DIR) + PROJECT scope via --dir"
else
  echo "configure: FATAL — --plugin-dir did not land on si-agent's command; the plugin (union) leg would be untested" >&2
  pty --root "$PR" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep "$SESS" >&2
  exit 1
fi
