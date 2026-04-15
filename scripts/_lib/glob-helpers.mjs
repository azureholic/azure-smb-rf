/**
 * File system glob/walk helpers.
 */

import fs from "node:fs";
import path from "node:path";

/**
 * Recursively find files with a given extension under a directory.
 * Returns relative paths. Returns empty array if dir doesn't exist.
 */
export function walkFiles(dir, ext) {
  const results = [];
  if (!fs.existsSync(dir)) return results;

  function walk(current) {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (entry.name.endsWith(ext)) {
        results.push(fullPath);
      }
    }
  }

  walk(dir);
  return results;
}
