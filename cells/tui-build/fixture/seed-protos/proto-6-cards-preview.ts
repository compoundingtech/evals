// proto-6: cards + preview pane.
// Top: 4-column grid of compact cards (each agent at-a-glance).
// Bottom: full-width preview pane = the SELECTED agent in detail with all resources.

import { layoutRoot, renderToAnsi, text, panel, column, row, hstack, themes } from "../../src/tui/index.ts";
import type { UINode } from "../../src/tui/nodes.ts";
import { AGENTS, statusColor, ageString } from "./data.ts";

const COLS = parseInt(process.env.COLUMNS ?? "140", 10);
const ROWS = parseInt(process.env.LINES ?? "60", 10);

const SELECTED = "orion";

const colorMuted: [number, number, number] = [120, 120, 140];
const colorAccent: [number, number, number] = [100, 180, 255];
const colorTag: [number, number, number] = [180, 150, 90];
const colorUrl: [number, number, number] = [120, 140, 180];
const colorBody: [number, number, number] = [220, 230, 255];
const colorRel: [number, number, number] = [120, 200, 140];
const colorParent: [number, number, number] = [80, 100, 140];
const colorWhite: [number, number, number] = [255, 255, 255];

function agentCard(identity: string): UINode {
  const a = AGENTS.find((x) => x.identity === identity)!;
  const [r, g, b] = statusColor(a.status);
  const isSel = identity === SELECTED;
  const titlePrefix = isSel ? "▸ " : "  ";
  const inboxStr = a.inbox > 0 ? `📬 ${a.inbox}` : "📭 0";
  return panel(
    `${titlePrefix}${a.identity}`,
    [
      row(
        text("●", { fg: [r, g, b] as [number, number, number] }),
        text(` ${a.status}`, { fg: colorBody }),
        text(`  ${a.role}`, { fg: colorMuted }),
      ),
      row(
        text(inboxStr, { fg: colorAccent }),
        text(`  ${ageString(a.lastActivityMs)}`, { fg: colorMuted }),
        text(`  📦 ${a.resources.length}`, { fg: colorRel }),
      ),
    ],
  );
}

function previewBlock(): UINode {
  const a = AGENTS.find((x) => x.identity === SELECTED)!;
  const [r, g, b] = statusColor(a.status);
  const header = row(
    text("● ", { fg: [r, g, b] as [number, number, number] }),
    text(a.identity, { bold: true, fg: colorWhite }),
    text(`  ·  ${a.role}`, { fg: colorMuted }),
    text(`  ·  parent: ${a.parent ?? "(root)"}`, { fg: colorMuted }),
    text(`  ·  ${a.status}`, { fg: colorBody }),
    text(`  ·  📬 ${a.inbox}`, { fg: colorAccent }),
    text(`  ·  ${ageString(a.lastActivityMs)} ago`, { fg: colorMuted }),
  );
  const resourceLines: UINode[] = [];
  for (const res of a.resources) {
    const title = res.title ?? res.id.split(":").slice(1).join(":");
    const tagStr = res.tags && res.tags.length > 0 ? `  [${res.tags.join(",")}]` : "";
    resourceLines.push(
      row(
        text("─ ", { fg: colorParent }),
        text(title, { bold: true, fg: colorBody }),
        text(tagStr, { fg: colorTag }),
        text(`  (${res.relation})`, { fg: colorRel }),
        text(`     ${res.url}`, { fg: colorUrl }),
      ),
    );
  }
  return panel(
    `preview — ${a.identity} · ${a.resources.length} resources`,
    [header, text(""), ...resourceLines],
  );
}

function build(): UINode[] {
  // Grid of cards: 4 columns
  const cols = 4;
  const colWidth = Math.floor((COLS - 4) / cols);
  const cardCols: UINode[][] = Array.from({ length: cols }, () => []);
  AGENTS.forEach((a, i) => {
    cardCols[i % cols].push(agentCard(a.identity));
  });
  const grid = hstack({ gap: 1 }, cardCols.map((children) => column({ width: colWidth }, children)));

  return [
    panel("proto-6 — cards (top) + preview pane (bottom) — selection: orion", [
      grid,
      text(""),
      previewBlock(),
    ]),
  ];
}

const nodes = build();
layoutRoot(nodes, { x: 0, y: 0, width: COLS, height: ROWS });
process.stdout.write(renderToAnsi(nodes, themes.coolBlue, "rounded", { spinnerChar: "·", fps: 0, showFPS: false }));
process.stdout.write("\n");
