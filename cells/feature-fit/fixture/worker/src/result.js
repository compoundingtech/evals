// The Result type used everywhere in tasklit. Code never throws for expected outcomes;
// it returns one of these. Success carries a value; failure carries a stable `code` + message.
export function ok(value) {
  return { ok: true, value };
}
export function fail(code, message) {
  return { ok: false, code, message };
}
