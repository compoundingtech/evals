# retry preset requirements

- `standard` remains the default and stays at three attempts with 100 and 300 millisecond delays.
- `resilient` is five attempts with 100, 300, 900, and 1800 millisecond delays.
- Defaults, schema, runtime, operator documentation, and tests must describe the same preset names and values.
- Resolved records and delay arrays remain immutable and independent of mutable input.
- This requirements document is protected during ordinary implementation.

