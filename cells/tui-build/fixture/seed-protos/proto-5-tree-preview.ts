// proto-5: tree + preview pane (master-detail).
// Left pane: hierarchical tree (proto-1 style) for navigation.
// Right pane: focused preview of the selected agent — header,
// metadata, and ALL its resources expanded.

import { layoutRoot, renderToAnsi, text, panel, column, row, hstack, themes } from "../../src/tui/index.ts";
import type { UINode } from "../../src/tui/nodes.ts";
import { AGENTS, childrenOf, statusColor, ageString } from "./data.ts";

const COLS = parseInt(process.env.COLUMNS ?? "140", 10);
const ROWS = parseInt(process.env.LINES ?? "60", 10);

const SELECTED = "orion";

const colorParent: [number, number, number] = [100, 100, 120];
const colorMuted: [number, number, number] = [120, 120, 140];
const colorAccent: [number, number, number] = [100, 180, 255];
const colorTag: [number, number, number] = [180, 150, 90];
const colorUrl: [number, number, number] = [120, 140, 180];
const colorBody: [number, number, number] = [220, 230, 255];
const colorRel: [number, number, number] = [120, 200, 140];

function treeRow(identity: string, depth: number): UINode {
  const a = AGENTS.find((x) => x.identity === identity)!;
  const isSel = identity === SELECTED;
  const [r, g, b] = statusColor(a.status);
  const indent = " ".repeat(depth * 2);
  const arrow = isSel ? "▸ " : "  ";
  const inbox = a.inbox > 0 ? `  📬${a.inbox}` : "";
  const tail = `  ${ageString(a.lastActivityMs)}`;
  return row(
    text(indent),
    text(arrow, { fg: isSel ? colorAccent : colorParent }),
    text("●", { fg: [r, g, b] as [number, number, number] }),
    text(" "),
    text(a.identity, { bold: isSel, fg: isSel ? [255, 255, 255] as [number, number, number] : colorBody }),
    text(`  [${a.role}]`, { fg: colorMuted }),
    text(inbox, { fg: colorAccent }),
    text(tail, { fg: colorMuted }),
  );
}

function buildTree(identity: string, depth: number, out: UINode[]): void {
  out.push(treeRow(identity, depth));
  for (const child of childrenOf(identity)) buildTree(child.identity, depth + 1, out);
}

function previewPane(): UINode {
  const a = AGENTS.find((x) => x.identity === SELECTED)!;
  const [r, g, b] = statusColor(a.status);
  const lines: UINode[] = [
    row(
      text("●", { fg: [r, g, b] as [number, number, number] }),
      text(" "),
      text(a.identity, { bold: true, fg: [255, 255, 255] as [number, number, number] }),
      text(`  [${a.role}]`, { fg: colorMuted }),
    ),
    row(
      text(`  status: ${a.status}`, { fg: colorMuted }),
      text(`    inbox: ${a.inbox}`, { fg: colorAccent }),
      text(`    last activity: ${ageString(a.lastActivityMs)} ago`, { fg: colorMuted }),
    ),
    row(
      text(`  parent: ${a.parent ?? "(root)"}`, { fg: colorMuted }),
    ),
    text(""),
    text(`Resources (${a.resources.length})`, { fg: colorAccent, bold: true }),
    text(""),
  ];
  for (const res of a.resources) {
    const title = res.title ?? res.id.split(":").slice(1).join(":");
    const tagStr = res.tags && res.tags.length > 0 ? `  [${res.tags.join(",")}]` : "";
    lines.push(
      row(
        text("─ ", { fg: colorParent }),
        text(title, { bold: true, fg: colorBody }),
        text(tagStr, { fg: colorTag }),
        text(`  (${res.relation})`, { fg: colorRel }),
      ),
      row(
        text("    "),
        text(res.url, { fg: colorUrl }),
      ),
      text(""),
    );
  }
  return column({ flex: true }, lines);
}

function build(): UINode[] {
  const treeLines: UINode[] = [
    text("agents", { bold: true, fg: colorAccent }),
    text(""),
  ];
  for (const root of AGENTS.filter((a) => a.parent === null)) {
    buildTree(root.identity, 0, treeLines);
  }
  const leftCol = column({ width: 52 }, treeLines);
  const rightCol = previewPane();
  return [
    panel("proto-5 — tree + preview pane (master-detail) — selection: orion", [
      hstack({ gap: 2 }, [leftCol, rightCol]),
    ]),
  ];
}

const nodes = build();
layoutRoot(nodes, { x: 0, y: 0, width: COLS, height: ROWS });
process.stdout.write(renderToAnsi(nodes, themes.coolBlue, "rounded", { spinnerChar: "·", fps: 0, showFPS: false }));
process.stdout.write("\n");
