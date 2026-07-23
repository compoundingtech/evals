// greetkit 2.0.0 — see CHANGELOG.md for breaking changes
export function greet(name) {
  return `Hello, ${name}!`;
}
export function goodbye(name) {
  return `Goodbye, ${name}!`;
}
export function greetFormal({ name, title }) {
  return `Good day, ${title} ${name}.`;
}
