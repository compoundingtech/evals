import { createServer } from "node:http";
import { computeStats } from "./stats.js";
import { record, valuesFor } from "./store.js";

// GET  /stats?metric=NAME   -> { count, sum, avg, p50, p95 } (numbers formatted to 2 decimals)
// POST /event  {metric,value} -> records a value
export function handle(req, res) {
  const url = new URL(req.url, "http://localhost");
  if (req.method === "GET" && url.pathname === "/stats") {
    const metric = url.searchParams.get("metric");
    const s = computeStats(valuesFor(metric));
    const body = JSON.stringify({
      metric,
      count: s.count,
      sum: s.sum,
      avg: s.avg.toFixed(2),
      p50: s.p50.toFixed(2), // TypeError if percentile returned undefined (small metric) -> 500
      p95: s.p95.toFixed(2),
    });
    res.writeHead(200, { "content-type": "application/json" });
    return res.end(body);
  }
  res.writeHead(404).end();
}

export function start(port = 8080) {
  const server = createServer((req, res) => {
    try {
      handle(req, res);
    } catch (err) {
      // Prod logs show: TypeError: Cannot read properties of undefined (reading 'toFixed')
      console.error(`[pulse] 500 on ${req.method} ${req.url}:`, err.message);
      res.writeHead(500, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: "internal error" }));
    }
  });
  server.listen(port, () => console.log(`[pulse] listening on :${port}`));
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) start();
