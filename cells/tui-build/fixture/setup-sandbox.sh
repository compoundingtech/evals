#!/usr/bin/env bash
# Materialize the tui-build eval sandbox: seed the `agent-viz` repo from the BUNDLED prototypes
# (fixture/seed-protos/), a bare origin, and one clone per agent. Deterministic + self-contained.
# Personas + `st launch` + the hermetic kick happen AFTER this (spin.sh). See ../task.toml.
#
#   ./setup-sandbox.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/tui-build
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTO="$HERE/seed-protos"          # bundled with the cell — no external repo needed

echo "== clean =="
rm -rf "$SB"; mkdir -p "$SB"
SEED="$SB/.seed"; mkdir -p "$SEED/src/views/tree" "$SEED/src/views/cards" "$SEED/src/data" "$SEED/test"

# ── rewrite helper: prototype imports -> the published @myobie/pty/tui seam ──
# `../../src/tui/<anything>.ts` -> `@myobie/pty/tui`  (index/nodes/types/input all re-export from the barrel)
lift() { sed -E 's#\.\./\.\./src/tui/[a-zA-Z]+\.ts#@myobie/pty/tui#g' "$1"; }

echo "== seed: lift prototypes (rewrite imports) =="
# tree+preview view (tui-tree's starting point) — proto-5
lift "$PROTO/proto-5-tree-preview.ts" | sed -E 's#\./data\.ts#../../data/mock.ts#g' > "$SEED/src/views/tree/index.ts"
# cards+preview view (tui-cards's starting point) — proto-6
lift "$PROTO/proto-6-cards-preview.ts" | sed -E 's#\./data\.ts#../../data/mock.ts#g' > "$SEED/src/views/cards/index.ts"
# mock data (self-contained synthetic roster; tests + reference)
cp "$PROTO/data.ts" "$SEED/src/data/mock.ts"
# real-network fetch (the shared data-layer basis: `st agents --enrich --json`) — the supervisor builds on this
lift "$PROTO/agent-network.ts" > "$SEED/src/data/network.ts"

echo "== seed: entry + package + config + docs =="
cat > "$SEED/src/index.ts" <<'TS'
// agent-viz entry — pick a view (tree|cards). The team wires this to the shared
// data layer in src/data/. Default reads the LIVE network; tests use the fixture.
const view = process.argv[2] ?? process.env.VIEW ?? "tree";
if (view === "cards") await import("./views/cards/index.ts");
else await import("./views/tree/index.ts");
TS

cat > "$SEED/package.json" <<'JSON'
{
  "name": "agent-viz",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "description": "A terminal UI to see the live smalltalk agent network — tree+preview and cards+preview, sharing one data layer.",
  "bin": { "agent-viz": "src/index.ts" },
  "scripts": {
    "start": "node --experimental-strip-types src/index.ts",
    "tree": "node --experimental-strip-types src/index.ts tree",
    "cards": "node --experimental-strip-types src/index.ts cards",
    "typecheck": "tsc --noEmit",
    "test": "node --experimental-strip-types --test test/"
  },
  "dependencies": { "@myobie/pty": "^0.10.0" },
  "devDependencies": { "typescript": "^5.6.0", "@types/node": "^22.0.0" }
}
JSON

cat > "$SEED/tsconfig.json" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "allowImportingTsExtensions": true,
    "noEmit": true,
    "strict": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["src", "test"]
}
JSON

cat > "$SEED/.gitignore" <<'GI'
node_modules/
.DS_Store
# eval agent infra — never commit into the product repo
CLAUDE.md
PERSONA.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
.seed/
GI

cat > "$SEED/README.md" <<'MD'
# agent-viz

A terminal UI to **see the live smalltalk agent network** at a glance — who's around,
their status, who has unread messages, and a preview of the selected agent. Two layouts
share one data layer:

- **tree** view + preview pane — `src/views/tree/`
- **cards** view + preview pane — `src/views/cards/`
- **shared data layer** — `src/data/` (`network.ts` reads `st agents --enrich --json`;
  `mock.ts` is fixture/reference data)

Built on `@myobie/pty/tui` (the published TUI framework).

## Run
```
npm install
npm start            # tree view (live network)
npm run cards        # cards view
npm test             # tests (use the frozen fixture, not the live network)
npm run typecheck
```

## Seeded from prototypes
`src/views/tree` and `src/views/cards` started as prototype tree+preview / cards+preview views.
They currently render **mock** data (`src/data/mock.ts`). The build is to wire both views to the
**real shared data layer** (`src/data/network.ts`) so they show the actual network, keep them
tested, and pass a real usability review.

## Reproducible data (tests + grading)
The live network changes; for tests + hermetic grading, point the data layer at a frozen
`ST_ROOT` fixture:
```
ST_ROOT="$PWD/../fixture/smalltalk" npm start
```
MD

echo "== git init seed + bare origin =="
git -C "$SEED" init -q -b main
git -C "$SEED" add -A
git -C "$SEED" -c user.name="eval-seed" -c user.email="seed@local" commit -q -m "seed: lift agent-viz prototypes (tree+cards+preview) onto @myobie/pty/tui"
SEED_COMMIT="$(git -C "$SEED" rev-parse --short HEAD)"
git clone -q --bare "$SEED" "$SB/origin.git"

echo "== clone one working copy per agent (distinct authors → isolation is attributable) =="
for a in sup tree cards ux; do
  git clone -q "$SB/origin.git" "$SB/$a"
  git -C "$SB/$a" remote set-url origin "$SB/origin.git"
  git -C "$SB/$a" config user.name  "tui-$a"
  git -C "$SB/$a" config user.email "tui-$a@eval.local"
done

echo "== materialize the frozen fixture (tests/grading) =="
"$HERE/generate-fixture.sh" "$SB/fixture/smalltalk" >/dev/null

echo
echo "SANDBOX READY: $SB   (seed $SEED_COMMIT)"
echo "  origin.git  sup/ tree/ cards/ ux/  fixture/smalltalk/"
echo "next: spin.sh — compose per-agent personas, launch each (st launch), seed the kick into tui-sup's inbox."
