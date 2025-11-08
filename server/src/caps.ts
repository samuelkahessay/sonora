// Centralized model capability helpers
// Use ESM import style; compiled output will be .js

/**
 * Whether Chat Completions should include a temperature parameter for a model.
 * GPT-5 family rejects temperature values (only supports default behavior),
 * so we omit the field to avoid 400 errors.
 */
export function chatCompletionsSupportsTemperature(model?: string): boolean {
  const m = (model || '').toLowerCase();
  // Treat all gpt-5 variants as not supporting temperature overrides
  return !(m.startsWith('gpt-5'));
}

