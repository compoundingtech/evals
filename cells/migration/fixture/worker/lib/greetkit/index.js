// greetkit 1.0.0
export function greet(name) {
  return `Hello, ${name}!`;
}
export function greetAll(names) {
  return names.map((n) => greet(n));
}
export function farewell(name) {
  return `Goodbye, ${name}.`;
}
export function greetFormal(name, title) {
  return `Good day, ${title} ${name}.`;
}
