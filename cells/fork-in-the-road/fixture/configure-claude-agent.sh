#!/usr/bin/env bash
# Launch one Fork-in-the-road Claude eval agent (sup|a|b|c) via the REAL `st launch`. st launch writes
# .mcp.json (server `st`), .claude/settings.local.json (asyncRewake/PreCompact/StopFailure hooks +
# enableAllProjectMcpServers + enabledMcpjsonServers:["st"]), session-id, pty.toml, installs the composed
# persona (--persona), and starts the pty session. We add the eval-only bits: ISOLATION (spin.sh exports
# ST_ROOT -> st launch bakes/inherits it -> the agent binds the isolated bus) + ZERO-ORPHAN teardown
# (--session-name "$(stev_prefix)" + stev_track_extra the exact name) + isolated coord dir + folder pre-trust.
# Posture (the operator): SUPERVISOR = bypassPermissions; PROPOSERS = auto.
#   ./configure-claude-agent.sh <sup|a|b|c> [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/fork-in-the-road}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent (standalone-safe)

case "$role" in
  sup) id="fd-sup"; d="$SB/sup"; mode="bypassPermissions" ;;   # coordinate-only, synthesizes RECOMMENDATION.md
  a)   id="fd-a";   d="$SB/a";   mode="auto" ;;
  b)   id="fd-b";   d="$SB/b";   mode="auto" ;;
  c)   id="fd-c";   d="$SB/c";   mode="auto" ;;
  *) echo "role must be sup|a|b|c" >&2; exit 1 ;;
esac
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh $role first" >&2; exit 1; }
pfx="$(stev_prefix "$SB" "$id")"     # stev-<cell>-<runid>-<id>
sess="$id-$pfx"                       # st launch names the pty session <identity>-<session-name>

# Pre-create the FULL coord dir on the ISOLATED bus so the boot ritual doesn't rabbit-hole.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder (deterministic; --unattended also auto-pokes the startup gates).
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real st launch. It inherits ST_ROOT/COORD_ROOT from this process (exported by spin.sh)
# and (post-#52) bakes ST_ROOT into the generated pty.toml env -> the agent binds the ISOLATED bus.
( cd "$d" && st launch claude \
    --identity "$id" \
    --session-name "$pfx" \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

stev_track_extra "$SB" "$sess"   # exact resulting session name -> zero-orphan teardown

echo "launched $id  (pty session=$sess, --permission-mode $mode, isolated bus=$ROOT, persona=$persona, asyncRewake)"
