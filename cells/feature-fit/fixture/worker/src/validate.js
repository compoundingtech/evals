// Shared input validators. Commands reuse these rather than inlining checks.
export function nonEmptyString(x) {
  return typeof x === "string" && x.trim().length > 0;
}
export function positiveInt(x) {
  return Number.isInteger(x) && x > 0;
}
