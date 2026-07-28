const PRESETS = Object.freeze({
  standard: Object.freeze({
    maxAttempts: 3,
    delaysMs: Object.freeze([100, 300]),
  }),
  resilient: Object.freeze({
    maxAttempts: 5,
    delaysMs: Object.freeze([100, 300, 900, 1800]),
  }),
});

export const defaultPreset = "standard";

export function resolveRetryPreset(name = defaultPreset) {
  const preset = PRESETS[name];
  if (!preset) {
    throw new TypeError(`unknown retry preset: ${name}`);
  }
  return Object.freeze({
    maxAttempts: preset.maxAttempts,
    delaysMs: Object.freeze([...preset.delaysMs]),
  });
}

