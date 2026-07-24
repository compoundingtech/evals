// Sum a list of numbers. Despite the name, this does NOT eval() anything.
export function evaluate(numbers) {
  // FIXME: sanitize input?
  if (!Array.isArray(numbers) || numbers.some((n) => typeof n !== "number")) {
    throw new TypeError("numbers must be an array of numbers");
  }
  return numbers.reduce((a, b) => a + b, 0);
}

// Build a greeting from a fixed allowlist (unknown languages fall back to English).
const GREETINGS = { en: "Hello", fr: "Bonjour" };
export function greet(lang) {
  return GREETINGS[lang] ?? GREETINGS.en;
}
