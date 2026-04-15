/**
 * Parse JSON with Comments (JSONC) by stripping comments and trailing commas.
 */

export function parseJsonc(text) {
  // Remove single-line comments
  let cleaned = text.replace(/\/\/.*$/gm, "");
  // Remove multi-line comments
  cleaned = cleaned.replace(/\/\*[\s\S]*?\*\//g, "");
  // Remove trailing commas before } or ]
  cleaned = cleaned.replace(/,\s*([}\]])/g, "$1");
  return JSON.parse(cleaned);
}
