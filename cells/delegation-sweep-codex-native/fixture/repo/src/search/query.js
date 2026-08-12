export function query(entries, term, limit = 10) {
  if (limit <= 0) limit = 10;
  const needle = term.trim().toLowerCase();
  if (!needle) return [];
  return entries.filter((entry) => entry.title.toLowerCase().includes(needle)).slice(0, limit);
}
