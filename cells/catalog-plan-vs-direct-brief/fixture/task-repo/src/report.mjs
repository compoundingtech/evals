export function parseJsonLines(text) {
  return text
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

export function summarize(records) {
  return records.map((record) => ({
    cell: record.cell,
    last_run: record.result,
  }));
}
