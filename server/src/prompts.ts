const SYSTEM_PROMPT = 'You are a JSON writer. Output ONLY valid minified JSON conforming to the provided schema. Do not include explanations or extra keys.';

export function buildPrompt(mode: string, transcript: string): { system: string; user: string } {
  const system = SYSTEM_PROMPT;
  
  let user: string;
  switch (mode) {
    case 'tldr':
    case 'analysis':
      user = `Transcript:\n<<<${transcript}>>>\nReturn {"summary": "...", "key_points": ["..."]}`;
      break;
    case 'themes':
      user = `Transcript:\n<<<${transcript}>>>\nReturn {"themes":[{"name":"...","evidence":["..."]}], "sentiment":"positive|neutral|mixed|negative"}`;
      break;
    case 'todos':
      user = `Transcript:\n<<<${transcript}>>>\nExtract actionable items user explicitly mentioned. Return {"todos":[{"text":"...","due":null}]}`;
      break;
    default:
      throw new Error(`Unknown mode: ${mode}`);
  }
  
  return { system, user };
}