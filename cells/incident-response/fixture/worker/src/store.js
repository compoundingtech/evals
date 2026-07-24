import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dir = dirname(fileURLToPath(import.meta.url));

// In-memory event store, seeded from data/events.json on boot ("prod" state).
const events = JSON.parse(readFileSync(join(__dir, "..", "data", "events.json"), "utf8"));

export function record(metric, value) {
  (events[metric] ??= []).push(value);
}

export function valuesFor(metric) {
  return events[metric] ?? [];
}

export function metrics() {
  return Object.keys(events);
}
