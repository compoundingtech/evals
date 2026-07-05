#!/usr/bin/env bash
# Materialize the Ghost-bug (debug) eval sandbox. A small `labelkit` lib with a SUBTLE, REAL
# cross-module bug: format.js does `Object.assign(defaultOptions, options)` — MUTATING the shared
# default object from config.js. So the first call with custom options permanently corrupts the
# defaults for every later call. The unit suite is GREEN (it never does a default-format AFTER a
# custom one), so the bug is a "ghost": latent, tests pass, manifests only via call interaction.
# Discriminator: ROOT-CAUSE (non-mutating merge) vs PAPER-OVER (freeze/reset/re-declare band-aids),
# and does the team ADD the regression test that would've caught it. See tasks/ghost-bug.toml.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/ghost-bug
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = coordinate-only, owns NO repo
W="$SB/worker"; mkdir -p "$W/src" "$W/test"

echo "== worker repo: labelkit, with the ghost bug =="
cat > "$W/src/config.js" <<'JS'
// Shared default formatting options. Consumers must NOT mutate this object.
export const defaultOptions = { prefix: "[", suffix: "]", pad: 1 };
JS

cat > "$W/src/format.js" <<'JS'
import { defaultOptions } from "./config.js";

// Format a label with optional overrides, e.g. format("ok") -> "[ ok ]".
export function format(label, options = {}) {
  const opts = Object.assign(defaultOptions, options);
  const p = " ".repeat(opts.pad);
  return `${opts.prefix}${p}${label}${p}${opts.suffix}`;
}
JS

cat > "$W/src/index.js" <<'JS'
export { format } from "./format.js";
export { defaultOptions } from "./config.js";
JS

# Existing suite: GREEN. Never formats with defaults AFTER a custom call, so the mutation is unseen.
cat > "$W/test/format.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { format } from "../src/format.js";

test("default formatting", () => {
  assert.equal(format("hi"), "[ hi ]");
});

test("custom prefix and suffix", () => {
  assert.equal(format("hi", { prefix: "<", suffix: ">" }), "< hi >");
});

test("zero padding (all fields specified)", () => {
  assert.equal(format("hi", { prefix: "[", suffix: "]", pad: 0 }), "[hi]");
});
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "labelkit",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "A tiny label-formatting library.",
  "main": "src/index.js",
  "scripts": { "test": "node --test" }
}
JSON

cat > "$W/README.md" <<'MD'
# labelkit

A tiny label-formatting library.

```js
import { format } from "./src/index.js";
format("ok");                       // "[ ok ]"
format("ok", { prefix: "<" });      // "<  ok ]"  (override just the prefix)
```

Defaults live in `src/config.js`; `format()` merges your overrides over them.
Run the tests with `npm test`.
MD

cat > "$W/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init worker repo (frozen base) + distinct author =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "labelkit: initial library"
git -C "$W" config user.name  "gb-fix"
git -C "$W" config user.email "gb-fix@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo "== sanity: suite is GREEN but the bug reproduces =="
( cd "$W" && node --test >/dev/null 2>&1 && echo "  suite: GREEN (as designed)" || echo "  !! suite unexpectedly RED" )
REPRO=$(cd "$W" && node --input-type=module -e '
import { format } from "./src/format.js";
format("a", { prefix: "<", suffix: ">" });
console.log(format("b"));   // buggy -> "< b >"; correct -> "[ b ]"
' 2>&1)
echo "  repro: format(custom) then format(default) => '$REPRO'  (bug if not '[ b ]')"

echo
echo "SANDBOX READY: $SB   (worker base $BASE; author gb-fix)"
echo "  worker/  labelkit (owned by gb-fix; GREEN suite, ghost mutation bug in src/format.js)"
echo "  sup/     coordinate-only (gb-sup cwd; owns no repo)"
echo "next: compose personas + wire agents (sup=bypass, fix=auto), seed the kick into gb-sup inbox, spin."
