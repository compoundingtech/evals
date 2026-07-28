const STANDARD = Object.freeze({
  maxAttempts: 3,
  delaysMs: Object.freeze([100, 300]),
});

const PRESETS = Object.freeze({
  standard: STANDARD,
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

