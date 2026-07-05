// agent-viz/data.ts — a SYNTHETIC agent + resource graph (the seed's placeholder data).
//
// This mock is invented (no real network). The views (tree / cards) start by rendering it;
// the eval's build task is to wire them to the real shared data layer (network.ts →
// `coord agents --enrich --json`) + the frozen fixture. The mock deliberately uses only the
// three statuses the proto type models — the LIVE/frozen network returns more (away / busy /
// dnd), and noticing + handling those is part of the usability pass.

export type AgentStatus = "available" | "unknown" | "offline";

export type Relation = "owns" | "relates-to" | "depends-on";

export interface Resource {
  /** Unique id (`<agent>:<short>`). */
  id: string;
  /** URL or session link or file path. */
  url: string;
  /** Optional human title. */
  title?: string;
  /** Optional tags. */
  tags?: string[];
  /** Relation to the OWNING agent. */
  relation: Relation;
}

export interface Agent {
  identity: string;
  status: AgentStatus;
  inbox: number;
  lastActivityMs: number;
  resources: Resource[];
  /** Implicit team hierarchy: parent identity (or null for root). */
  parent: string | null;
  /** Optional role label (lead / specialist / standalone). */
  role: "chief-of-staff" | "lead" | "specialist" | "standalone" | "user";
}

const now = 1782718800000;
const minAgo = (m: number) => now - m * 60_000;

export const AGENTS: Agent[] = [
  {
    identity: "atlas",
    status: "available",
    inbox: 2,
    lastActivityMs: minAgo(3),
    parent: null,
    role: "chief-of-staff",
    resources: [
      { id: "atlas:cfg", url: "repo://acme/atlas-config", title: "atlas config", tags: ["index"], relation: "owns" },
      { id: "atlas:session", url: "stream://atlas", title: "session", relation: "owns" },
    ],
  },
  {
    identity: "nova",
    status: "available",
    inbox: 0,
    lastActivityMs: minAgo(11),
    parent: "atlas",
    role: "specialist",
    resources: [
      { id: "nova:repo", url: "repo://acme/widgets", title: "widgets", relation: "owns" },
      { id: "nova:session", url: "stream://nova", relation: "owns" },
    ],
  },
  {
    identity: "sol",
    status: "unknown",
    inbox: 3,
    lastActivityMs: minAgo(1240),
    parent: "atlas",
    role: "lead",
    resources: [
      { id: "sol:repo", url: "repo://acme/pipeline", title: "pipeline", tags: ["service"], relation: "owns" },
      { id: "sol:session", url: "stream://sol", relation: "owns" },
    ],
  },
  {
    identity: "vega",
    status: "offline",
    inbox: 0,
    lastActivityMs: minAgo(4360),
    parent: "sol",
    role: "specialist",
    resources: [
      { id: "vega:repo", url: "repo://acme/vega-svc", title: "vega service", relation: "owns" },
      // cross-agent edge: vega's service depends on sol's pipeline
      { id: "vega:dep", url: "repo://acme/pipeline", title: "pipeline", relation: "depends-on" },
    ],
  },
  {
    identity: "orion",
    status: "available",
    inbox: 12,
    lastActivityMs: minAgo(1),
    parent: "sol",
    role: "specialist",
    resources: [
      { id: "orion:repo", url: "repo://acme/orion-ui", title: "orion ui", relation: "owns" },
      { id: "orion:site", url: "https://example.com/orion", title: "preview", relation: "relates-to" },
    ],
  },
  {
    identity: "lyra",
    status: "unknown",
    inbox: 1,
    lastActivityMs: minAgo(90),
    parent: null,
    role: "standalone",
    resources: [
      { id: "lyra:repo", url: "repo://acme/lyra-docs", title: "lyra docs", tags: ["docs"], relation: "owns" },
    ],
  },
  {
    identity: "echo",
    status: "offline",
    inbox: 0,
    lastActivityMs: minAgo(2880),
    parent: "atlas",
    role: "specialist",
    resources: [
      { id: "echo:session", url: "stream://echo", relation: "owns" },
    ],
  },
];

export function childrenOf(parent: string): Agent[] {
  return AGENTS.filter((a) => a.parent === parent);
}

/** Find an agent by identity. */
export function findAgent(id: string): Agent | undefined {
  return AGENTS.find((a) => a.identity === id);
}

/** All cross-agent edges derived from resources whose target URL matches another agent's repo or session. */
export interface Edge {
  from: string;       // agent identity (source)
  to: string;         // agent identity (target)
  relation: Relation;
}

export function deriveEdges(): Edge[] {
  const edges: Edge[] = [];
  for (const a of AGENTS) {
    for (const r of a.resources) {
      // Map a resource URL to whichever agent OWNS that repo/session (host-agnostic).
      for (const t of AGENTS) {
        if (t.identity === a.identity) continue;
        const owned = t.resources.find(
          (x) => x.relation === "owns" && (x.url.startsWith("repo://") || x.url.startsWith("stream://"))
        );
        if (owned && r.url === owned.url) {
          edges.push({ from: a.identity, to: t.identity, relation: r.relation });
          break;
        }
      }
    }
  }
  return edges;
}

/** Human-readable label for relation. */
export function relationLabel(r: Relation): string {
  return r;
}

/** Color hint for status (RGB). */
export function statusColor(s: AgentStatus): [number, number, number] {
  if (s === "available") return [80, 200, 120];
  if (s === "unknown") return [180, 180, 180];
  return [240, 100, 100];
}

export function ageString(lastMs: number): string {
  const ms = Date.now() - lastMs;
  if (ms < 60_000) return `${Math.round(ms / 1000)}s`;
  if (ms < 3_600_000) return `${Math.round(ms / 60_000)}m`;
  if (ms < 86_400_000) return `${Math.round(ms / 3_600_000)}h`;
  return `${Math.round(ms / 86_400_000)}d`;
}
