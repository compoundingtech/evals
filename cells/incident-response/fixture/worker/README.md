# pulse

A tiny in-memory metrics service.

- `POST /event` `{ "metric": "latency", "value": 123 }` — record a sample.
- `GET /stats?metric=latency` — `{ count, sum, avg, p50, p95 }`.

Percentiles use the **nearest-rank** method: the p-quantile is the sample at 1-based
rank `ceil(p * N)` in the ascending-sorted values (e.g. p50 of 15 samples is the 8th smallest).

State is seeded from `data/events.json` on boot. Run the tests with `npm test`; start with `npm start`.
