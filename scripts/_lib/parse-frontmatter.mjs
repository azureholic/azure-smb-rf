/**
 * Simple YAML frontmatter parser for agent/skill/instruction markdown files.
 */

/**
 * Parse YAML frontmatter between --- delimiters.
 * Returns a plain object or null if no frontmatter found.
 */
export function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return null;

  const yaml = match[1];
  const result = {};
  let currentKey = null;
  let currentArray = null;

  for (const line of yaml.split("\n")) {
    // Array continuation: "  - value"
    if (/^\s+-\s+/.test(line) && currentKey) {
      const value = line.replace(/^\s+-\s+/, "").trim();
      if (!currentArray) {
        currentArray = [];
        result[currentKey] = currentArray;
      }
      currentArray.push(parseValue(value));
      continue;
    }

    // Inline array: "key: [a, b, c]"
    const inlineArrayMatch = line.match(
      /^([A-Za-z][\w-]*):\s*\[([^\]]*)\]\s*$/,
    );
    if (inlineArrayMatch) {
      currentKey = inlineArrayMatch[1];
      currentArray = null;
      const items = inlineArrayMatch[2]
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
        .map(parseValue);
      result[currentKey] = items;
      continue;
    }

    // Key-value: "key: value"
    const kvMatch = line.match(/^([A-Za-z][\w-]*):\s*(.*)$/);
    if (kvMatch) {
      currentKey = kvMatch[1];
      currentArray = null;
      const rawValue = kvMatch[2].trim();
      if (
        rawValue === "" ||
        rawValue === ">" ||
        rawValue === "|" ||
        rawValue === ">-" ||
        rawValue === "|-"
      ) {
        // Block scalar or empty — next lines are continuation, but we skip block parsing for simplicity
        result[currentKey] = rawValue === "" ? "" : rawValue;
      } else {
        result[currentKey] = parseValue(rawValue);
      }
      continue;
    }

    // Continuation line for block scalars
    if (currentKey && /^\s+/.test(line) && !currentArray) {
      const prev = result[currentKey];
      const trimmed = line.trim();
      if (
        typeof prev === "string" &&
        (prev === ">" ||
          prev === "|" ||
          prev === ">-" ||
          prev === "|-" ||
          prev === "")
      ) {
        result[currentKey] = trimmed;
      } else if (typeof prev === "string") {
        result[currentKey] = prev + " " + trimmed;
      }
    }
  }

  return result;
}

function parseValue(raw) {
  if (raw === "true") return true;
  if (raw === "false") return false;
  if (raw === "null" || raw === "~") return null;
  // Quoted strings
  if (
    (raw.startsWith('"') && raw.endsWith('"')) ||
    (raw.startsWith("'") && raw.endsWith("'"))
  ) {
    return raw.slice(1, -1);
  }
  // Numbers
  if (/^-?\d+(\.\d+)?$/.test(raw)) return Number(raw);
  return raw;
}

/**
 * Return the body content after frontmatter.
 */
export function getBody(content) {
  const match = content.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n?([\s\S]*)$/);
  return match ? match[1] : content;
}
