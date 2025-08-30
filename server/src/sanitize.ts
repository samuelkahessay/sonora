export function sanitizeTranscript(transcript: string): string {
  let s = transcript ?? '';
  // Normalize line endings
  s = s.replace(/\r\n?/g, '\n');
  // Remove null bytes and most control characters except tab/newline
  s = [...s].filter((ch) => {
    const code = ch.codePointAt(0) ?? 0;
    if (code === 0x09 || code === 0x0a) return true;
    return code >= 0x20 && code <= 0x10ffff;
  }).join('');
  // Defang our delimiter tokens to avoid premature closing
  s = s.replaceAll('<<<', '‹‹‹').replaceAll('>>>', '›››');
  // Defang common markdown fences
  s = s.replaceAll('```', '``\u200A');
  return s;
}

