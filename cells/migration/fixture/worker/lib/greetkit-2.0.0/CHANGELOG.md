# greetkit — changelog

## 2.0.0 (BREAKING)
- **Removed** `greetAll(names)`. Compose with the array you already have: `names.map(greet)`.
- **Renamed** `farewell(name)` → `goodbye(name)`, and its message now ends with `!` instead of `.`
  — `goodbye("Ana")` returns `"Goodbye, Ana!"`.
- **Changed** `greetFormal(name, title)` to take a single options object: `greetFormal({ name, title })`.
- `greet(name)` is unchanged.

## 1.0.0
- Initial release: `greet`, `greetAll`, `farewell`, `greetFormal`.
