/**
 * Markdown H2 heading and section parser.
 */

/**
 * Extract all H2 heading lines from markdown content.
 * Returns lines like "## Overview" (with the ## prefix).
 */
export function extractH2Headings(content) {
  return content
    .split("\n")
    .filter((line) => /^## /.test(line))
    .map((line) => line.trimEnd());
}

/**
 * Split markdown into sections by H2 headings.
 * Returns array of { heading, lines } where heading is the text
 * after "## " (without the prefix) and lines contains all lines
 * in that section (until the next H2 or EOF).
 */
export function extractH2Sections(content) {
  const allLines = content.split("\n");
  const sections = [];
  let current = null;

  for (const line of allLines) {
    if (/^## /.test(line)) {
      if (current) sections.push(current);
      current = { heading: line.replace(/^## /, "").trimEnd(), lines: [] };
    } else if (current) {
      current.lines.push(line);
    }
  }
  if (current) sections.push(current);

  return sections;
}
