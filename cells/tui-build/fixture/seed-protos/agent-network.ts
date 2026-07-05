// agent-network.ts — interactive hybrid TUI for browsing the smalltalk
// agent network. Tree-nav on the left, live `pty peek` of the selected
// agent's session in the right preview pane. Built on pty/tui.
//
// The "build it to usable" reference: real `coord agents --enrich --json`
// for the agent list; real `pty peek` for the preview; arrow keys for
// navigation; `q` or `Ctrl+\` to quit.
//
// Run:
//   node --experimental-strip-types examples/agent-viz/agent-network.ts
//
// Prereqs:
//   - smalltalk/coord installed (`coord agents --json` works)
//   - target agents have running pty sessions (peek requires alive)

import { execFileSync, spawnSync } from "node:child_process";
import {
  app, screen, text, panel, row, column, hstack, themes,
  signal, effect, scrollable,
  layoutRoot, renderToAnsi,
} from "../../src/tui/index.ts";
import type { UINode, ScreenContext } from "../../src/tui/types.ts";
import type { KeyEvent } from "../../src/tui/input.ts";

// ─── Data fetching ─────────────────────────────────────────────────────

interface AgentRow {
  identity: string;
  status: "available" | "unknown" | "offline" | "busy" | "dnd";
  inbox: number;
  lastActivityMs: number | null;
  tasks: { todo: number; doing: number; done: number; blocked: number };
}

function fetchAgents(): AgentRow[] {
  try {
    const out = execFileSync("coord", ["agents", "--enrich", "--json"], {
      encoding: "utf8",
      timeout: 5000,
    });
    // CLI prints a one-line warning when honoring COORD_* legacy env; skip
    // non-JSON prefix lines defensively.
    const lines = out.split("\n").filter((l) => l.trim().length > 0);
    const jsonLine = lines.find((l) => l.trimStart().startsWith("[")) ?? "[]";
    const parsed = JSON.parse(jsonLine);
    return parsed.map((m: any) => ({
      identity: m.identity,
      status: m.status,
      inbox: m.inbox ?? 0,
      lastActivityMs: m.lastActivity ?? null,
      tasks: m.tasks ?? { todo: 0, doing: 0, done: 0, blocked: 0 },
    }));
  } catch {
    return [];
  }
}

function peekSession(sessionName: string, height: number, width: number): string {
  // pty peek returns ANSI-formatted output by default — we want plain so we
  // can re-render it through our own theme (otherwise nested ANSI escapes
  // clash with the surrounding layout). --plain strips ANSI but preserves
  // visible content. --full would dump scrollback; we want only the visible
  // window.
  const result = spawnSync("pty", ["peek", "--plain", sessionName], {
    encoding: "utf8",
    timeout: 2000,
  });
  if (result.error || (result.status !== null && result.status !== 0)) {
    const stderr = (result.stderr ?? "").trim();
    if (stderr.includes("not found")) return `(no pty session: ${sessionName})`;
    return `(pty peek failed: ${stderr.slice(0, 200)})`;
  }
  const raw = result.stdout ?? "";
  // Clip to fit the preview pane
  const lines = raw.split("\n").slice(0, height - 4); // leave header room
  return lines.map((l) => l.slice(0, width - 4)).join("\n");
}

function ageString(lastMs: number | null): string {
  if (lastMs === null) return "—";
  const ms = Date.now() - lastMs;
  if (ms < 60_000) return `${Math.round(ms / 1000)}s`;
  if (ms < 3_600_000) return `${Math.round(ms / 60_000)}m`;
  if (ms < 86_400_000) return `${Math.round(ms / 3_600_000)}h`;
  return `${Math.round(ms / 86_400_000)}d`;
}

function statusColor(s: AgentRow["status"]): [number, number, number] {
  switch (s) {
    case "available": return [80, 200, 120];
    case "busy":      return [240, 180, 80];
    case "dnd":       return [240, 100, 100];
    case "offline":   return [180, 100, 100];
    default:          return [160, 160, 180];
  }
}

// ─── State ────────────────────────────────────────────────────────────

const agents = signal<AgentRow[]>(fetchAgents());
const selectedIndex = signal<number>(0);
const previewContent = signal<string>("(loading…)");
const lastRefreshMs = signal<number>(Date.now());

function refreshPreview(): void {
  const list = agents.get();
  if (list.length === 0) {
    previewContent.set("(no agents found — is coord installed?)");
    return;
  }
  const idx = Math.max(0, Math.min(selectedIndex.get(), list.length - 1));
  const agent = list[idx];
  // Try peeking — agents have pty sessions matching their identity.
  const text = peekSession(agent.identity, 50, 90);
  previewContent.set(text);
}

effect(() => {
  // Re-fetch preview whenever selection changes.
  selectedIndex.get();
  refreshPreview();
});

// ─── Render ───────────────────────────────────────────────────────────

const colorAccent: [number, number, number] = [100, 180, 255];
const colorMuted: [number, number, number]  = [120, 120, 140];
const colorBody: [number, number, number]   = [220, 230, 255];
const colorWhite: [number, number, number]  = [255, 255, 255];
const colorParent: [number, number, number] = [100, 100, 120];

function agentTreeRow(a: AgentRow, isSelected: boolean): UINode {
  const [r, g, b] = statusColor(a.status);
  const arrow = isSelected ? "▸ " : "  ";
  const inbox = a.inbox > 0 ? ` 📬${a.inbox}` : "";
  const doing = a.tasks.doing > 0 ? ` ⚙${a.tasks.doing}` : "";
  const age = a.lastActivityMs !== null ? ageString(a.lastActivityMs) : "—";
  return row(
    text(arrow, { fg: isSelected ? colorAccent : colorParent }),
    text("●", { fg: [r, g, b] as [number, number, number] }),
    text(" "),
    text(a.identity, { bold: isSelected, fg: isSelected ? colorWhite : colorBody }),
    text(inbox, { fg: colorAccent }),
    text(doing, { fg: [120, 200, 140] as [number, number, number] }),
    text(`  ${age}`, { fg: colorMuted }),
  );
}

function leftPane(): UINode {
  const list = agents.get();
  const sel = selectedIndex.get();
  const lines: UINode[] = [
    text("agents", { bold: true, fg: colorAccent }),
    text(`  ${list.length} total · refresh: r · quit: q`, { fg: colorMuted }),
    text(""),
  ];
  list.forEach((a, i) => lines.push(agentTreeRow(a, i === sel)));
  return column({ width: 44 }, lines);
}

function rightPane(): UINode {
  const list = agents.get();
  const sel = selectedIndex.get();
  if (list.length === 0) {
    return column({ flex: true }, [text("(no agents)")]);
  }
  const agent = list[Math.min(sel, list.length - 1)];
  const [r, g, b] = statusColor(agent.status);
  const previewLines = previewContent.get().split("\n").map((line) =>
    text(line, { fg: colorBody }),
  );
  return column({ flex: true }, [
    row(
      text("●", { fg: [r, g, b] as [number, number, number] }),
      text(" "),
      text(agent.identity, { bold: true, fg: colorWhite }),
      text(`  ${agent.status}`, { fg: colorBody }),
      text(`  📬 ${agent.inbox}`, { fg: colorAccent }),
      text(`  ⚙ todo=${agent.tasks.todo} doing=${agent.tasks.doing} done=${agent.tasks.done}`, { fg: colorMuted }),
      text(`  ${ageString(agent.lastActivityMs)}`, { fg: colorMuted }),
    ),
    text(""),
    text("─ live pty peek ─", { bold: true, fg: colorMuted }),
    text(""),
    ...previewLines,
  ]);
}

const root = screen({
  id: "agent-network",
  render: (_ctx: ScreenContext): UINode[] => [
    panel("agent-network — hybrid tree-nav + live pty peek preview", [
      hstack({ gap: 2 }, [leftPane(), rightPane()]),
    ]),
  ],
  handleKey: (key: KeyEvent, _ctx) => {
    if (key.key === "q") {
      runner.stop();
      return true;
    }
    if (key.key === "up" || (key.ctrl && key.key === "p")) {
      const sel = selectedIndex.get();
      selectedIndex.set(Math.max(0, sel - 1));
      return true;
    }
    if (key.key === "down" || (key.ctrl && key.key === "n")) {
      const sel = selectedIndex.get();
      selectedIndex.set(Math.min(agents.get().length - 1, sel + 1));
      return true;
    }
    if (key.key === "r") {
      agents.set(fetchAgents());
      lastRefreshMs.set(Date.now());
      refreshPreview();
      return true;
    }
    return false;
  },
});

const runner = app({ screen: root, theme: () => themes.coolBlue });
runner.start();
