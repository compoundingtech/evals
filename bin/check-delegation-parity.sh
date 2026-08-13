#!/usr/bin/env bash
# Model-free matching and oracle-validity gate for the 12-cell delegation-parity tournament.
#
# It proves two things without starting a model:
#   1. MATCHING — within one task, the four arms differ only in the delegation layer. Task bytes, held-out
#      graders, the frozen baseline repository, the deliverable contract, and the timeout are identical, and
#      the graders and mutation inputs are never visible inside a fixture.
#   2. ORACLE VALIDITY — a complete correct outcome passes every gating judge in both the st2 and the native
#      bus shape, and each preregistered planted failure is rejected by the judge that is supposed to catch it.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tasks=(sweep review implement)
arms=(claude-st2 claude-native codex-st2 codex-native)

scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# ── 1. matching ────────────────────────────────────────────────────────────────────────────────────────────
reference_arm=claude-st2
for task in "${tasks[@]}"; do
  ref="cells/delegation-$task-$reference_arm"
  [ -d "$ref" ] || fail "delegation-$task-$reference_arm is missing"
  for arm in "${arms[@]}"; do
    cell="cells/delegation-$task-$arm"
    [ -d "$cell" ] || fail "delegation-$task-$arm is missing"

    cmp -s "$ref/task.md" "$cell/task.md" ||
      fail "delegation-$task-$arm has a different frozen task than $reference_arm"
    cmp -s "$ref/judges/grade.sh" "$cell/judges/grade.sh" ||
      fail "delegation-$task-$arm has a different outcome grader than $reference_arm"
    cmp -s "$ref/judges/observe.sh" "$cell/judges/observe.sh" ||
      fail "delegation-$task-$arm has a different observation recorder than $reference_arm"
    cmp -s "$ref/judges/repo.sha256" "$cell/judges/repo.sha256" ||
      fail "delegation-$task-$arm has a different frozen baseline manifest than $reference_arm"
    cmp -s "$ref/fixture/findings/CONTRACT.md" "$cell/fixture/findings/CONTRACT.md" ||
      fail "delegation-$task-$arm has a different deliverable contract than $reference_arm"
    diff -r "$ref/fixture/repo" "$cell/fixture/repo" >/dev/null ||
      fail "delegation-$task-$arm has a different product repository than $reference_arm"
    if [ -d "$ref/mutations" ]; then
      diff -r "$ref/mutations" "$cell/mutations" >/dev/null ||
        fail "delegation-$task-$arm has different held-out mutation inputs than $reference_arm"
    fi
    if [ -d "$ref/fixture/review" ]; then
      diff -r "$ref/fixture/review" "$cell/fixture/review" >/dev/null ||
        fail "delegation-$task-$arm has a different proposal under review than $reference_arm"
    fi

    ref_timeout="$(grep -E '^[[:space:]]*max-timeout ' "$ref/delegation-$task-$reference_arm.kdl")"
    arm_timeout="$(grep -E '^[[:space:]]*max-timeout ' "$cell/delegation-$task-$arm.kdl")"
    [ "$ref_timeout" = "$arm_timeout" ] ||
      fail "delegation-$task-$arm declares $arm_timeout, not the matched $ref_timeout"

    ref_kickoff="$(grep -E '^[[:space:]]*to "' "$ref/delegation-$task-$reference_arm.kdl")"
    arm_kickoff="$(grep -E '^[[:space:]]*to "' "$cell/delegation-$task-$arm.kdl")"
    [ "$ref_kickoff" = "$arm_kickoff" ] ||
      fail "delegation-$task-$arm delivers the kickoff to $arm_kickoff, not the matched $ref_kickoff"

    # Held-out assets must never be reachable from an agent's world.
    if find "$cell/fixture" -type f \
      \( -name 'grade.sh' -o -name 'observe.sh' -o -name 'repo.sha256' -o -name '*-slug.js' -o -name '*-test.js' \) |
      grep -q .; then
      fail "delegation-$task-$arm leaks a held-out grader or mutation input into its fixture"
    fi

    seats="$(grep -cE '^  agent "' "$cell/delegation-$task-$arm.kdl")"
    case "$arm" in
    *-native)
      [ "$seats" -eq 1 ] ||
        fail "delegation-$task-$arm is a native arm with $seats bus seats; a native arm delegates without peers"
      grep -q 'grade.sh delegation native' "$cell/delegation-$task-$arm.kdl" ||
        fail "delegation-$task-$arm does not grade native delegation evidence"
      ;;
    *-st2)
      [ "$seats" -ge 2 ] ||
        fail "delegation-$task-$arm is an st2 arm with $seats bus seat(s); it needs a coordinator and delegates"
      grep -q 'grade.sh delegation st2' "$cell/delegation-$task-$arm.kdl" ||
        fail "delegation-$task-$arm does not grade bus delegation evidence"
      ;;
    esac
  done

  # The frozen manifest must describe the shipped fixture exactly.
  ( cd "$ref/fixture" && sha256sum -c --quiet "$repo_root/$ref/judges/repo.sha256" >/dev/null 2>&1 ) ||
    fail "delegation-$task baseline manifest does not match the shipped fixture repository"
done

# The shared delegation layer is itself matched: one coordinator persona per arm kind, one delegate persona.
for task in "${tasks[@]}"; do
  cmp -s cells/delegation-sweep-claude-st2/fixture/sup/PERSONA.md \
    "cells/delegation-$task-claude-st2/fixture/sup/PERSONA.md" ||
    fail "the st2 coordinator persona differs between tasks"
  cmp -s cells/delegation-sweep-claude-st2/fixture/sup/PERSONA.md \
    "cells/delegation-$task-codex-st2/fixture/sup/AGENTS.md" ||
    fail "the st2 coordinator persona differs between harnesses"
  cmp -s cells/delegation-sweep-claude-st2/fixture/w1/PERSONA.md \
    "cells/delegation-$task-claude-st2/fixture/w1/PERSONA.md" ||
    fail "the st2 delegate persona differs between tasks"
  cmp -s cells/delegation-sweep-claude-native/fixture/sup/PERSONA.md \
    "cells/delegation-$task-claude-native/fixture/sup/PERSONA.md" ||
    fail "the Claude native coordinator persona differs between tasks"
  cmp -s cells/delegation-sweep-codex-native/fixture/sup/AGENTS.md \
    "cells/delegation-$task-codex-native/fixture/sup/AGENTS.md" ||
    fail "the codex native coordinator persona differs between tasks"
done

# The st2 coordinator can only delegate to identities it can name: a hermetic eval catalog holds no Agent Spec
# declarations on disk, so roster discovery there reports the fixture's own files instead of the peer seats.
# Every declared delegate identity must therefore appear verbatim in the shared coordinator persona.
sup_persona=cells/delegation-sweep-claude-st2/fixture/sup/PERSONA.md
for task in "${tasks[@]}"; do
  kdl="cells/delegation-$task-claude-st2/delegation-$task-claude-st2.kdl"
  team="$(sed -n 's/^team "\([^"]*\)".*/\1/p' "$kdl" | head -1)"
  [ -n "$team" ] || fail "delegation-$task-claude-st2 declares no team prefix"
  while IFS= read -r seat; do
    [ "$seat" = sup ] && continue
    grep -Fq "\`$team.$seat\`" "$sup_persona" ||
      fail "the st2 coordinator persona never names the declared delegate $team.$seat"
  done < <(sed -n 's/^  agent "\([^"]*\)".*/\1/p' "$kdl")
done

# The deliverable contract is arm-neutral, but it must not contradict a persona that requires a delegation log.
for task in "${tasks[@]}"; do
  grep -Fq 'delegation-log.md' "cells/delegation-$task-claude-st2/fixture/findings/CONTRACT.md" ||
    fail "the delegation-$task deliverable contract does not admit the native delegation log it is graded on"
done

# Each native persona must actually name its harness spawn surface, and no st2 persona may name one.
grep -q '`Agent` tool' cells/delegation-sweep-claude-native/fixture/sup/PERSONA.md ||
  fail "the Claude native persona does not name the Agent tool"
grep -q 'spawn_agent' cells/delegation-sweep-codex-native/fixture/sup/AGENTS.md ||
  fail "the codex native persona does not name spawn_agent"
if grep -qE 'Agent. tool|spawn_agent' cells/delegation-sweep-claude-st2/fixture/sup/PERSONA.md; then
  fail "the st2 coordinator persona names a harness-native spawn tool"
fi

printf 'PASS: %d delegation-parity cells match within each task and hold their graders out\n' \
  "$(( ${#tasks[@]} * ${#arms[@]} ))"

# ── 2. the baseline world behaves as the frozen tasks claim ────────────────────────────────────────────────
baseline="$scratch/baseline"
cp -a cells/delegation-sweep-claude-st2/fixture/repo "$baseline"
( cd "$baseline" && node --test >/dev/null 2>&1 ) ||
  fail "the baseline product repository does not start with a green suite"

patched="$scratch/patched"
cp -a "$baseline" "$patched"
( cd "$patched" && git apply "$repo_root/cells/delegation-review-claude-st2/fixture/review/proposed.patch" ) ||
  fail "the reviewed proposal does not apply to the frozen baseline"
( cd "$patched" && node --test >/dev/null 2>&1 ) ||
  fail "the reviewed proposal is not green, so the review task's premise is false"

cmp -s cells/delegation-implement-claude-st2/mutations/baseline-slug.js \
  cells/delegation-implement-claude-st2/fixture/repo/src/slug.js ||
  fail "the held-out pre-change implementation is not the one shipped in the fixture"

printf 'PASS: the baseline suite is green, the reviewed proposal applies and stays green, and the frozen pre-change implementation matches\n'

# ── 3. oracle validity ────────────────────────────────────────────────────────────────────────────────────
counter=0
put_msg() { # put_msg <mailbox-dir> <unix-ms> <from>
  counter=$((counter + 1))
  mkdir -p "$1"
  printf 'from: %s\nto: peer\n\nsynthetic oracle message\n' "$3" > "$1/$2-o${counter}aa.md"
}

team_of() { # every cell uses one uniform team prefix, which is what lets one persona name its delegates
  printf 'dg\n'
}

workers_of() {
  case "$1" in
  implement) printf 'w1\n' ;;
  *) printf 'w1\nw2\n' ;;
  esac
}

build_catalog() { # build_catalog <name> <task> <st2|native> -> catalog path
  local name="$1" task="$2" shape="$3"
  local root="$scratch/$name" team worker
  team="$(team_of "$task")"
  rm -rf -- "$root"
  mkdir -p "$root" "$root/requester/inbox" "$root/requester/archive" \
    "$root/evalhost.$team.sup/inbox" "$root/evalhost.$team.sup/archive"
  cp -a "cells/delegation-$task-claude-st2/fixture/." "$root/"
  put_msg "$root/evalhost.$team.sup/archive" 1780000000000 requester
  if [ "$shape" = st2 ]; then
    while IFS= read -r worker; do
      mkdir -p "$root/evalhost.$team.$worker/inbox" "$root/evalhost.$team.$worker/archive"
      put_msg "$root/evalhost.$team.$worker/archive" 1780000010000 "evalhost.$team.sup"
      put_msg "$root/evalhost.$team.sup/archive" 1780000020000 "evalhost.$team.$worker"
    done < <(workers_of "$task")
  fi
  put_msg "$root/requester/inbox" 1780000030000 "evalhost.$team.sup"
  printf '%s\n' "$root"
}

judge() { # judge <task> <catalog> <mode> [arm]
  local task="$1" catalog="$2"
  shift 2
  CATALOG="$catalog" ST_ROOT="$catalog" SPEC_DIR="$repo_root/cells/delegation-$task-claude-st2" \
    bash "cells/delegation-$task-claude-st2/judges/grade.sh" "$@"
}

expect_pass() { # expect_pass <label> <task> <catalog> <mode> [arm]
  local label="$1"
  shift
  local out
  if ! out="$(judge "$@" 2>&1)"; then
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    fail "$label should have passed"
  fi
}

expect_fail() { # expect_fail <label> <task> <catalog> <mode> [arm]
  local label="$1"
  shift
  local out
  if out="$(judge "$@" 2>&1)"; then
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    fail "$label was accepted; the oracle does not discriminate"
  fi
  grep -q '^FAIL:' <<< "$out" || {
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    fail "$label failed without an explanatory FAIL receipt"
  }
}

# --- sweep -------------------------------------------------------------------------------------------------
sweep_answer() { # sweep_answer <catalog> <shape>
  local root="$1" shape="$2"
  {
    printf 'delegate: dg.w1\nslice: 1\n\n## Call sites\n'
    printf -- '- repo/src/render/card.js — imports legacyTitle directly\n'
    printf -- '- repo/src/render/list.js — via the compat alias\n'
    printf -- '- repo/src/export/markdown.js — via the compat alias\n'
  } > "$root/findings/slice-1.md"
  {
    printf 'delegate: dg.w2\nslice: 2\n\n## Call sites\n'
    printf -- '- repo/src/compat/title-helpers.js — calls resolveTitle\n'
    printf -- '- repo/src/search/index-entry.js — via titleFor\n'
    printf -- '- repo/scripts/backfill-titles.js — imports legacyTitle directly\n'
  } > "$root/findings/slice-2.md"
  {
    printf '## Call sites\n'
    printf -- '- repo/scripts/backfill-titles.js\n- repo/src/compat/title-helpers.js\n'
    printf -- '- repo/src/export/markdown.js\n- repo/src/render/card.js\n- repo/src/render/list.js\n'
    printf -- '- repo/src/search/index-entry.js\n\n## Notes\nUnion checked against both slices.\n'
  } > "$root/findings/summary.md"
  if [ "$shape" = native ]; then
    printf 'delegate: slice-1-explorer slice: 1 tool: Agent\ndelegate: slice-2-explorer slice: 2 tool: Agent\n' \
      > "$root/findings/delegation-log.md"
  fi
}

complete_st2="$(build_catalog sweep-complete-st2 sweep st2)"
sweep_answer "$complete_st2" st2
expect_pass "the complete sweep outcome" sweep "$complete_st2" outcome
expect_pass "the complete sweep slices" sweep "$complete_st2" slices
expect_pass "the untouched sweep repository" sweep "$complete_st2" isolation
expect_pass "the complete sweep bus delegation" sweep "$complete_st2" delegation st2

complete_native="$(build_catalog sweep-complete-native sweep native)"
sweep_answer "$complete_native" native
expect_pass "the complete native sweep outcome" sweep "$complete_native" outcome
expect_pass "the complete native sweep delegation" sweep "$complete_native" delegation native
expect_fail "a native sweep judged as an st2 arm" sweep "$complete_native" delegation st2

naive="$(build_catalog sweep-naive sweep st2)"
sweep_answer "$naive" st2
{
  printf '## Call sites\n'
  printf -- '- repo/src/render/card.js\n- repo/src/compat/index.js\n- repo/src/render/preview.js\n'
  printf -- '- repo/src/audit/report.js\n- repo/scripts/backfill-titles.js\n'
} > "$naive/findings/summary.md"
expect_fail "a text-search sweep answer" sweep "$naive" outcome

lonely="$(build_catalog sweep-one-delegate sweep st2)"
sweep_answer "$lonely" st2
sed -i 's/^delegate: dg.w2$/delegate: dg.w1/' "$lonely/findings/slice-2.md"
expect_fail "two sweep slices claimed by one delegate" sweep "$lonely" slices

missing="$(build_catalog sweep-missing-slice sweep st2)"
sweep_answer "$missing" st2
rm "$missing/findings/slice-2.md"
expect_fail "a sweep with a missing slice deliverable" sweep "$missing" slices

dirty="$(build_catalog sweep-dirty sweep st2)"
sweep_answer "$dirty" st2
printf '\n// touched during a read-only audit\n' >> "$dirty/repo/src/render/card.js"
expect_fail "a read-only sweep that edited the repository" sweep "$dirty" isolation

added="$(build_catalog sweep-added sweep st2)"
sweep_answer "$added" st2
printf 'scratch\n' > "$added/repo/notes.txt"
expect_fail "a read-only sweep that added a file to the repository" sweep "$added" isolation

leaked="$(build_catalog sweep-bus-leak sweep native)"
sweep_answer "$leaked" native
mkdir -p "$leaked/evalhost.dg.helper/inbox"
expect_fail "a native sweep that grew a second bus seat" sweep "$leaked" delegation native

unlogged="$(build_catalog sweep-unlogged sweep native)"
sweep_answer "$unlogged" native
rm "$unlogged/findings/delegation-log.md"
expect_fail "a native sweep with no recorded delegation" sweep "$unlogged" delegation native

silent="$(build_catalog sweep-silent-worker sweep st2)"
sweep_answer "$silent" st2
find "$silent/evalhost.dg.sup/archive" -name '*.md' -exec grep -l 'from: evalhost.dg.w2' {} + |
  xargs -r rm
expect_fail "an st2 sweep where a delegate never reported" sweep "$silent" delegation st2

# Formatting tolerance: a correct answer written with bold paths and a numbered list is still correct.
formatted="$(build_catalog sweep-formatted sweep st2)"
sweep_answer "$formatted" st2
{
  printf '## Call sites\n'
  printf '1. **repo/scripts/backfill-titles.js** — direct import\n'
  printf '2. **repo/src/compat/title-helpers.js**\n'
  printf '3. `repo/src/export/markdown.js`\n'
  printf '4. **repo/src/render/card.js**\n'
  printf '5. _repo/src/render/list.js_\n'
  printf '6. **repo/src/search/index-entry.js** — via titleFor\n'
} > "$formatted/findings/summary.md"
expect_pass "a correct sweep answer written with bold and numbered items" sweep "$formatted" outcome

printf 'PASS: the sweep oracle accepts a complete answer in both bus shapes and two markdown styles, and rejects 8 planted failures\n'

# --- review ------------------------------------------------------------------------------------------------
review_answer() { # review_answer <catalog> <shape>
  local root="$1" shape="$2"
  {
    printf 'delegate: dg.w1\nslice: 1\n\n## Defects\n'
    printf -- '- repo/src/export/markdown.js — Object.assign mutates the shared DEFAULTS object, so the first custom call corrupts every later export\n'
    printf '\n## Cleared\n- repo/src/util/clamp.js — the rewrite is behaviour-preserving\n'
  } > "$root/findings/review-1.md"
  {
    printf 'delegate: dg.w2\nslice: 2\n\n## Defects\n'
    printf -- '- repo/src/search/query.js — the guard became `limit < 0`, so limit=0 now returns nothing instead of the default page\n'
    printf -- '- repo/src/sort.js — the comparator returns a boolean instead of a number, so the sort order is undefined\n'
    printf '\n## Cleared\n- repo/test/query.test.js — the new shape covers strictly more\n'
  } > "$root/findings/review-2.md"
  {
    printf '## Defects\n'
    printf -- '- repo/src/export/markdown.js — mutates the shared DEFAULTS object\n'
    printf -- '- repo/src/search/query.js — a limit of 0 now yields nothing\n'
    printf -- '- repo/src/sort.js — boolean comparator, so ordering is undefined\n'
    printf '\n## Notes\nBoth slice reviews were re-read against the patch.\n'
  } > "$root/findings/summary.md"
  if [ "$shape" = native ]; then
    printf 'delegate: reviewer-a slice: 1 tool: spawn_agent\ndelegate: reviewer-b slice: 2 tool: spawn_agent\n' \
      > "$root/findings/delegation-log.md"
  fi
}

rc_st2="$(build_catalog review-complete-st2 review st2)"
review_answer "$rc_st2" st2
expect_pass "the complete review outcome" review "$rc_st2" outcome
expect_pass "the complete review slices" review "$rc_st2" slices
expect_pass "the untouched reviewed repository" review "$rc_st2" isolation
expect_pass "the complete review bus delegation" review "$rc_st2" delegation st2

rc_native="$(build_catalog review-complete-native review native)"
review_answer "$rc_native" native
expect_pass "the complete native review outcome" review "$rc_native" outcome
expect_pass "the complete native review delegation" review "$rc_native" delegation native

shotgun="$(build_catalog review-shotgun review st2)"
review_answer "$shotgun" st2
{
  printf '## Defects\n'
  printf -- '- repo/src/export/markdown.js — mutates shared DEFAULTS\n'
  printf -- '- repo/src/search/query.js — limit handling changed\n'
  printf -- '- repo/src/sort.js — boolean comparator\n'
  printf -- '- repo/src/util/clamp.js — rewritten, looks risky\n'
  printf -- '- repo/test/query.test.js — the test was changed\n'
} > "$shotgun/findings/summary.md"
expect_fail "a review that reported every changed file" review "$shotgun" outcome

partial="$(build_catalog review-partial review st2)"
review_answer "$partial" st2
{
  printf '## Defects\n'
  printf -- '- repo/src/export/markdown.js — mutates shared DEFAULTS\n'
  printf -- '- repo/src/search/query.js — a limit of 0 now yields nothing\n'
} > "$partial/findings/summary.md"
expect_fail "a review that missed the comparator defect" review "$partial" outcome

bare="$(build_catalog review-bare review st2)"
review_answer "$bare" st2
{
  printf '## Defects\n'
  printf -- '- repo/src/export/markdown.js\n- repo/src/search/query.js\n- repo/src/sort.js\n'
} > "$bare/findings/summary.md"
expect_fail "a review that named no mechanism" review "$bare" outcome

decoy="$(build_catalog review-decoy review st2)"
review_answer "$decoy" st2
{
  printf 'delegate: dg.w2\nslice: 2\n\n## Defects\n'
  printf -- '- repo/src/search/query.js — a limit of 0 now yields nothing\n'
  printf -- '- repo/src/sort.js — boolean comparator\n'
  printf -- '- repo/test/query.test.js — the test was weakened\n'
} > "$decoy/findings/review-2.md"
expect_fail "a review slice that flagged a behaviour-preserving hunk" review "$decoy" slices

printf 'PASS: the review oracle accepts a complete review in both bus shapes and rejects 4 planted failures\n'

# --- implement ---------------------------------------------------------------------------------------------
mut=cells/delegation-implement-claude-st2/mutations

implement_reports() { # implement_reports <catalog> <shape>
  local root="$1" shape="$2"
  {
    printf 'delegate: dg.w1\nslice: 1\n\n## Approach\nA per-base counter assigns -2, -3 in input order.\n'
    printf '\n## Files\n- repo/src/slug.js\n- repo/test/slug.test.js\n'
    printf '\n## Regression evidence\nThe new collision test is red on the previous implementation.\n'
  } > "$root/findings/slice-1.md"
  printf '## Verification\nSuite green, both worked examples hold, replay red on the old implementation.\n' \
    > "$root/findings/summary.md"
  if [ "$shape" = native ]; then
    printf 'delegate: slug-implementer slice: 1 tool: Agent\n' > "$root/findings/delegation-log.md"
  fi
}

ic_st2="$(build_catalog implement-complete-st2 implement st2)"
cp "$mut/solution-slug.js" "$ic_st2/repo/src/slug.js"
cp "$mut/solution-test.js" "$ic_st2/repo/test/slug.test.js"
implement_reports "$ic_st2" st2
expect_pass "the complete implementation outcome" implement "$ic_st2" outcome
expect_pass "the complete implementation suite" implement "$ic_st2" suite
expect_pass "the complete implementation regression replay" implement "$ic_st2" regression
expect_pass "the complete implementation reports" implement "$ic_st2" slices
expect_pass "the scoped implementation" implement "$ic_st2" isolation
expect_pass "the complete implementation bus delegation" implement "$ic_st2" delegation st2

ic_native="$(build_catalog implement-complete-native implement native)"
cp "$mut/solution-slug.js" "$ic_native/repo/src/slug.js"
cp "$mut/solution-test.js" "$ic_native/repo/test/slug.test.js"
implement_reports "$ic_native" native
expect_pass "the complete native implementation outcome" implement "$ic_native" outcome
expect_pass "the complete native implementation delegation" implement "$ic_native" delegation native

untouched="$(build_catalog implement-untouched implement st2)"
implement_reports "$untouched" st2
expect_fail "an unimplemented feature" implement "$untouched" outcome
expect_fail "an unchanged implementation file" implement "$untouched" isolation

wrong="$(build_catalog implement-wrong implement st2)"
cp "$mut/wrong-slug.js" "$wrong/repo/src/slug.js"
cp "$mut/solution-test.js" "$wrong/repo/test/slug.test.js"
implement_reports "$wrong" st2
expect_fail "a wrong collision counter" implement "$wrong" outcome
expect_fail "a wrong collision counter under its own suite" implement "$wrong" suite

theatre="$(build_catalog implement-weak-test implement st2)"
cp "$mut/solution-slug.js" "$theatre/repo/src/slug.js"
cp "$mut/weak-test.js" "$theatre/repo/test/slug.test.js"
implement_reports "$theatre" st2
expect_pass "a correct implementation with a weak test still behaves" implement "$theatre" outcome
expect_fail "a regression test that is green on the old implementation" implement "$theatre" regression

wide="$(build_catalog implement-wide implement st2)"
cp "$mut/solution-slug.js" "$wide/repo/src/slug.js"
cp "$mut/solution-test.js" "$wide/repo/test/slug.test.js"
implement_reports "$wide" st2
printf '\n// unrelated drive-by edit\n' >> "$wide/repo/src/sort.js"
expect_fail "an implementation that edited outside its slice" implement "$wide" isolation

unreported="$(build_catalog implement-unreported implement st2)"
cp "$mut/solution-slug.js" "$unreported/repo/src/slug.js"
cp "$mut/solution-test.js" "$unreported/repo/test/slug.test.js"
implement_reports "$unreported" st2
rm "$unreported/findings/slice-1.md"
expect_fail "an implementation with no delegate report" implement "$unreported" slices

pruned="$(build_catalog implement-pruned implement st2)"
cp "$mut/solution-slug.js" "$pruned/repo/src/slug.js"
cp "$mut/solution-test.js" "$pruned/repo/test/slug.test.js"
implement_reports "$pruned" st2
rm "$pruned/repo/test/legacy-title.test.js"
expect_pass "a pruned suite still runs green" implement "$pruned" suite
expect_fail "an implementation that deleted a baseline test file" implement "$pruned" isolation

printf 'PASS: the implementation oracle accepts a complete change in both bus shapes and rejects 8 planted failures\n'

# ── 4. the observation recorder is inert and non-gating ───────────────────────────────────────────────────
observed="$(build_catalog observe-shape sweep st2)"
sweep_answer "$observed" st2
probe_spec="$scratch/probe/cells/delegation-observe"
mkdir -p "$probe_spec/judges"
cp cells/delegation-sweep-claude-st2/judges/observe.sh "$probe_spec/judges/observe.sh"
obs_out="$(
  CATALOG="$observed" ST_ROOT="$observed" SPEC_DIR="$probe_spec" \
    bash "$probe_spec/judges/observe.sh" claude-st2
)"
grep -q '^OBSERVED ' <<< "$obs_out" || {
  printf '%s\n' "$obs_out" | sed 's/^/  /' >&2
  fail "the observation recorder printed no row"
}
# The synthetic bus puts the kickoff at 1780000000000 and the confirmation 30 s later.
grep -qP '\t30000\t' <<< "$obs_out" || {
  printf '%s\n' "$obs_out" | sed 's/^/  /' >&2
  fail "the observation recorder did not derive the 30000 ms bus latency from the mailbox timestamps"
}
sink="$scratch/probe/.eval-runs/observations/delegation-observe.tsv"
[ -s "$sink" ] || fail "the observation recorder wrote no durable row to .eval-runs/observations"
[ "$(wc -l < "$sink")" -eq 2 ] || fail "the observation sink should hold one header and one row"

printf 'PASS: the observation recorder derives a bus latency, writes a durable row, and never gates\n'
printf 'PASS: delegation-parity matching and oracle validity hold\n'
