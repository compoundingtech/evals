#!/usr/bin/env bash
set -euo pipefail

repo="${STREAM_GH_REPO:?STREAM_GH_REPO is required}"
pr="${STREAM_GH_PR:?STREAM_GH_PR is required}"
max_attempts="${STREAM_GH_MAX_ATTEMPTS:-30}"
poll_seconds="${STREAM_GH_POLL_SECONDS:-2}"
gh_bin="${STREAM_GH_BIN:-gh}"
st2_bin="${STREAM_ST2_BIN:-st2}"
emit_attempts="${STREAM_EMIT_MAX_ATTEMPTS:-5}"
emit_backoff="${STREAM_EMIT_INITIAL_BACKOFF_SECONDS:-1}"

case "$max_attempts" in ''|*[!0-9]*) echo "STREAM_GH_MAX_ATTEMPTS must be a positive integer" >&2; exit 2;; esac
case "$poll_seconds" in ''|*[!0-9.]*) echo "STREAM_GH_POLL_SECONDS must be a non-negative number" >&2; exit 2;; esac
test "$max_attempts" -gt 0 || { echo "STREAM_GH_MAX_ATTEMPTS must be positive" >&2; exit 2; }

pr_json="$("$gh_bin" pr view "$pr" --repo "$repo" --json number,url,headRefOid,state)"
number="$(jq -er '.number' <<<"$pr_json")"
url="$(jq -er '.url' <<<"$pr_json")"
head="$(jq -er '.headRefOid' <<<"$pr_json")"

for attempt in $(seq 1 "$max_attempts"); do
  set +e
  checks="$("$gh_bin" pr checks "$pr" --repo "$repo" --json name,state,bucket,workflow,link)"
  checks_status="$?"
  set -e
  if test "$checks_status" -ne 0 && test "$checks_status" -ne 8; then
    printf 'gh pr checks failed with status %s\n' "$checks_status" >&2
    exit "$checks_status"
  fi
  summary="$(jq -cer 'sort_by(.workflow, .name) | map({workflow,name,state,bucket,link})' <<<"$checks")"
  count="$(jq 'length' <<<"$summary")"
  pending="$(jq '[.[] | select(.bucket == "pending")] | length' <<<"$summary")"
  failed="$(jq '[.[] | select(.bucket == "fail" or .bucket == "cancel")] | length' <<<"$summary")"
  unknown="$(jq '[.[] | select(.bucket != "pass" and .bucket != "pending" and .bucket != "fail" and .bucket != "cancel" and .bucket != "skipping")] | length' <<<"$summary")"
  if test -n "${STREAM_GH_TRACE_FILE:-}"; then
    jq -cn --argjson attempt "$attempt" --argjson count "$count" --argjson pending "$pending" \
      --argjson failed "$failed" --argjson unknown "$unknown" --argjson checks "$summary" \
      '{attempt:$attempt,count:$count,pending:$pending,failed:$failed,unknown:$unknown,checks:$checks}' \
      >>"$STREAM_GH_TRACE_FILE"
  fi

  if test "$count" -gt 0 && test "$pending" -eq 0 && test "$unknown" -eq 0; then
    if test "$failed" -eq 0; then conclusion="success"; else conclusion="failure"; fi
    message="$(jq -cn \
      --argjson pr "$number" --arg repo "$repo" --arg url "$url" --arg head "$head" \
      --arg conclusion "$conclusion" --argjson checks "$summary" \
      '{kind:"github-pr-ci",repo:$repo,pr:$pr,url:$url,head:$head,conclusion:$conclusion,checks:$checks}')"
    content_id="$(sha256sum <<<"$message" | cut -c1-16)"
    for emit_attempt in $(seq 1 "$emit_attempts"); do
      set +e
      emitted="$("$st2_bin" event emit "${ST_AGENT:?ST_AGENT is required}" \
        --stream github-ci \
        --event-id "github-pr-$number-$head-$conclusion-$content_id" \
        --key "github:$repo#$number" \
        --supersede \
        --subject "GitHub PR #$number CI $conclusion" \
        --message "$message" \
        --host stream \
        --json 2>&1)"
      emit_status="$?"
      set -e
      if test "$emit_status" -eq 0; then
        printf '%s\n' "$emitted"
        if test "${STREAM_KEEP_ALIVE:-1}" = 1; then exec sleep "${STREAM_KEEP_ALIVE_SECONDS:-300}"; fi
        exit 0
      fi
      if test "$emit_attempt" -lt "$emit_attempts"; then
        sleep "$emit_backoff"
        emit_backoff="$(awk -v delay="$emit_backoff" 'BEGIN { delay *= 2; if (delay > 8) delay = 8; print delay }')"
      fi
    done
    printf '%s\n' "$emitted" >&2
    echo "failed to publish terminal GitHub PR CI result after $emit_attempts attempts" >&2
    exit 75
  fi

  if test "$attempt" -lt "$max_attempts"; then sleep "$poll_seconds"; fi
done

echo "GitHub PR $repo#$number checks did not reach a terminal state after $max_attempts attempts" >&2
exit 75
