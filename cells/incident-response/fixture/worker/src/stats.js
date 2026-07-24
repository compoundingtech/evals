// Aggregate metric statistics for the pulse service.
//
// Percentiles use the NEAREST-RANK method: the p-quantile is the sample at
// 1-based rank ceil(p * N) in the ascending-sorted values, i.e. the
// (ceil(p*N))-th smallest sample. (So p50 of 15 sorted samples is the 8th.)
export function percentile(values, p) {
  const sorted = [...values].sort((a, b) => a - b);
  const rank = Math.ceil(p * sorted.length); // 1-based nearest rank
  return sorted[rank];                        // returns the rank-th sample (0-based indexing)
}

// Summary stats for a metric's recorded values.
export function computeStats(values) {
  const count = values.length;
  const sum = values.reduce((a, b) => a + b, 0);
  const avg = count ? sum / count : 0;
  return {
    count,
    sum,
    avg,
    p50: percentile(values, 0.5),
    p95: percentile(values, 0.95),
  };
}
