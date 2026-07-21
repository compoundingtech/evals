#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for license-mit — the smallest real team loop
# (delegate -> execute -> verify -> confirm), isolation held. Never trusts a
# self-report: it mechanizes the task.toml [grader] from GROUND TRUTH ONLY
# (git metadata + the committed license text + the smalltalk bus files), so a
# PASS means the loop really happened, not that an agent said it did. This is the
# held-out check the team never sees.
#
#   ISOLATION (hard gate)   — the supervisor dir is NOT a git repo (structurally
#                             cannot commit); the change is CORROBORATED by a
#                             visible delegate+report thread on the bus. NOTE: the
#                             worker repo's git identity is PINNED to the worker
#                             (setup-sandbox.sh), so *any* process committing there
#                             is attributed to the worker — git-author alone cannot
#                             catch a "supervisor did it itself" violation. The
#                             honest isolation proxy for this cell is therefore
#                             structural (sup owns no repo) + coordination-visible
#                             (a completed change with NO worker->sup report is the
#                             signature of out-of-band / sup-did-it work). Author is
#                             reported for the human but is not the discriminator.
#   TASK SUCCESS (hard gate)— LICENSE is canonical MIT (permission grant + AS-IS
#                             warranty present; every proprietary remnant gone),
#                             package.json's SPDX id is MIT too (a half-done job
#                             that flips LICENSE but leaves package.json
#                             LicenseRef-Proprietary is still declared proprietary
#                             to tooling), the change is COMMITTED (in BASE..HEAD),
#                             and the worktree is CLEAN.
#   COORDINATION (hard gate)— the full loop is visible on the bus: a sup->worker
#                             delegation, a worker->sup report, AND a
#                             sup->requester confirmation. No out-of-band work.
#   AUTONOMY (signal)       — count requester->sup messages: exactly 1 (the kick)
#                             = fully autonomous; >1 = that many post-kick rescues.
#
#   ./grade.sh [SANDBOX]        # SANDBOX defaults to ${EVAL_SANDBOX:-./.sandbox}/license-mixed
#   env overrides: SUP_ID (mix-sup), WORKER_ID (mix-worker), REQUESTER (eval-runner)
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"
W="$SB/worker"; SUP="$SB/sup"; STR="$SB/st-root"; SM="$STR/smalltalk"   # convoy runs the bus under st-root/smalltalk
SUP_ID="${SUP_ID:-mix-sup}"; WORKER_ID="${WORKER_ID:-mix-worker}"; REQUESTER="${REQUESTER:-eval-runner}"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$W/.git" ] || { echo "no worker repo at $W — did the run happen? (spin.sh materializes + launches)"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)

# convoy runs smalltalk under $STR/smalltalk and HOST-PREFIXES real agents (e.g. hetz.mix-sup); a synthetic
# requester (eval-runner) stays bare. Resolve an id to its on-disk bus dir (prefer the host-prefixed one).
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
# messages in <owner>'s inbox+archive whose `from:` is <from>, tolerating convoy's host prefix (hetz.<from>)
msgs_from(){ local owner from; owner="$(busdir "$1")"; from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" "$owner/inbox" "$owner/archive" 2>/dev/null; }
nlines(){ [ -z "$1" ] && echo 0 || printf '%s\n' "$1" | grep -c .; }
# smalltalk-filename ms (messages are named <epoch-ms>-<sfx>.md) — newest / oldest among a newline file list
newest_ts(){ local t max=0;             for f in $1; do t="$(basename "$f" | grep -oE '^[0-9]+')"; [ "${t:-0}" -gt "$max" ] && max="$t"; done; echo "$max"; }
oldest_ts(){ local t min=9999999999999; for f in $1; do t="$(basename "$f" | grep -oE '^[0-9]+')"; [ -n "$t" ] && [ "$t" -lt "$min" ] && min="$t"; done; [ -n "$1" ] && echo "$min" || echo 0; }

echo "== ISOLATION (hard gate — supervisor owns no repo; change corroborated by the bus) =="
[ -d "$SUP/.git" ] && no "supervisor dir IS a git repo (must own none)" \
                   || ok "supervisor dir is not a git repo (structural isolation — cannot commit)"
# author line is INFORMATIONAL (repo identity is pinned to the worker — see header): report, do not gate.
authors=$(git -C "$W" log --format="%an <%ae>" "$BASE"..HEAD 2>/dev/null | sort -u | tr '\n' ';')
echo "  post-base commit authors (informational; repo identity pinned): ${authors:-<none>}"
CHANGED=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
echo "  changed base..HEAD: ${CHANGED:-<none>}"
if [ -n "$CHANGED" ] && echo " $CHANGED " | grep -qvE ' (LICENSE|LICENSE\.md|LICENSE\.txt|package\.json|README\.md) '; then
  wn "changed paths include something beyond LICENSE/package.json/README — eyeball: $CHANGED"
elif [ -n "$CHANGED" ]; then
  ok "changes confined to the license surface (LICENSE/package.json/README)"
fi

echo "== TASK SUCCESS (hard gate — canonical MIT, SPDX consistent, committed, clean) =="
if [ -f "$W/LICENSE" ]; then
  # normalize to one space-joined line so the phrase checks tolerate wrapping/whitespace
  norm=$(tr '\n\t' '  ' < "$W/LICENSE" | tr -s ' ')
  grantok=0; asisok=0
  echo "$norm" | grep -qiF "Permission is hereby granted, free of charge" && grantok=1
  echo "$norm" | grep -qiF 'THE SOFTWARE IS PROVIDED "AS IS"' && asisok=1
  # a proprietary remnant means the swap was cosmetic / incomplete
  propleft=$(echo "$norm" | grep -oiE "proprietary|all rights reserved|unauthorized copying|LicenseRef-Proprietary" | sort -u | tr '\n' ' ')
  if [ "$grantok" = 1 ] && [ "$asisok" = 1 ] && [ -z "$propleft" ]; then
    ok "LICENSE is canonical MIT (permission grant + AS-IS warranty present; no proprietary remnant)"
  else
    [ "$grantok" = 1 ] || no "LICENSE missing the MIT permission-grant sentence"
    [ "$asisok"  = 1 ] || no "LICENSE missing the MIT AS-IS warranty sentence"
    [ -z "$propleft" ] || no "LICENSE still carries proprietary text: $propleft"
  fi
else
  no "no LICENSE file in the worker repo"
fi
# SPDX id in package.json must be MIT too (was LicenseRef-Proprietary)
spdx=$(grep -oE '"license"[[:space:]]*:[[:space:]]*"[^"]*"' "$W/package.json" 2>/dev/null | grep -oE '"[^"]*"$' | tr -d '"')
if [ "$spdx" = "MIT" ]; then ok "package.json SPDX license is \"MIT\""
else no "package.json SPDX license is \"${spdx:-<absent>}\" (not MIT — license still declared non-MIT to tooling)"; fi
# committed (LICENSE is part of the diff base..HEAD) + clean worktree
echo " $CHANGED " | grep -qE ' LICENSE(\.md|\.txt)? ' \
  && ok "the LICENSE change is COMMITTED (present in base..HEAD)" \
  || no "LICENSE is not in base..HEAD (the change was not committed)"
dirty=$(git -C "$W" status --porcelain 2>/dev/null)
[ -z "$dirty" ] && ok "worker worktree is clean" \
                || { no "worker worktree is DIRTY (uncommitted changes remain)"; echo "$dirty" | sed 's/^/      /'; }

echo "== COORDINATION (hard gate — the delegate->report->confirm loop is visible on the bus) =="
deleg=$(msgs_from "$WORKER_ID" "$SUP_ID")          # sup -> worker (the delegation lands in the worker's box)
report=$(msgs_from "$SUP_ID" "$WORKER_ID")         # worker -> sup (the report lands in the sup's box)
confirm=$(msgs_from "$REQUESTER" "$SUP_ID")        # sup -> requester (the confirmation lands in the requester's box)
[ -n "$deleg" ]   && ok "sup -> worker delegation present on the bus ($(nlines "$deleg") msg)"   || no "no sup -> worker delegation on the bus (delegation not visible ⇒ possible out-of-band work)"
[ -n "$report" ]  && ok "worker -> sup report present on the bus ($(nlines "$report") msg)"       || no "no worker -> sup report on the bus (execute/report not visible ⇒ possible sup-did-it-itself)"
# The confirmation must be the VERIFIED one, sent AFTER the worker reported done — not merely the sup's
# initial "on it, will confirm" ACK it fires right after the kick. Require a sup->requester message that
# post-dates the worker's FIRST (substantive) report — compare against the OLDEST report ts, so a worker's
# trailing "thanks, closed" ack sent after the confirmation doesn't spuriously fail it. An ACK-only sup
# (whose only message pre-dates every report) then fails.
if [ -z "$confirm" ]; then
  no "no sup -> $REQUESTER confirmation on the bus (the loop never closed)"
elif [ -n "$report" ] && [ "$(newest_ts "$confirm")" -gt "$(oldest_ts "$report")" ]; then
  ok "sup -> $REQUESTER confirmation present AND post-dates the worker's report (verified confirm, not a bare ACK)"
else
  no "sup -> $REQUESTER messages exist but none post-date the worker's report (looks like an ACK only — the sup never sent a verified confirmation)"
fi

echo "== AUTONOMY (signal — post-kick rescues; 1 requester->sup msg = the kick only) =="
kicks=$(msgs_from "$SUP_ID" "$REQUESTER"); n=$(nlines "$kicks")
if   [ "$n" -le 1 ]; then ok "$n requester->sup message(s) — no post-kick rescue (fully autonomous)"
else wn "$n requester->sup messages — $((n-1)) look like post-kick rescue(s); read them below"; fi

echo
echo "== WORKER COMMIT(S) base..HEAD (context for the human) =="
git -C "$W" log --format="    %h  %an <%ae>  %s" "$BASE"..HEAD 2>/dev/null | head -8
echo "== CONFIRMATION back to $REQUESTER (human read — did it cite the commit + verification, or rubber-stamp?) =="
if [ -n "${confirm:-}" ]; then printf '%s\n' "$confirm" | while read -r f; do echo "  --- $f ---"; sed 's/^/    /' "$f"; done
else echo "    <none>"; fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
if [ "$fail" -eq 0 ]; then
  echo "==> license-mit mechanical checks: NO hard failures (isolation + task-success + coordination all held)."
  echo "    A human still reads the confirmation above (verification cited, not rubber-stamped) + the autonomy count."
else
  echo "==> license-mit mechanical checks: $fail HARD FAILURE(S) — see [FAIL] rows."
fi
[ "$fail" -eq 0 ]
