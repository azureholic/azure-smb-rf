#!/usr/bin/env node
/**
 * JSON Syntax Validator
 *
 * Validates all JSON files in the workspace using a single Node.js process
 * instead of spawning a new process per file via shell find/exec.
 *
 * @example
 * node scripts/lint-json.mjs
 */

import fs from "node:fs";
import path from "node:path";

const EXCLUDE_DIRS = new Set([
  "node_modules",
  "infra",
  ".devcontainer",
  ".vscode",
  ".git",
]);

// fs.globSync requires Node 22+. Use a portable recursive walk instead so the
// script runs on Node 21 as well.
function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (EXCLUDE_DIRS.has(entry.name)) continue;
      walk(path.join(dir, entry.name), out);
    } else if (entry.isFile() && entry.name.endsWith(".json")) {
      out.push(path.join(dir, entry.name));
    }
  }
  return out;
}

const files = walk(".").map((f) => f.replace(/^\.\//, ""));

let failures = 0;

for (const file of files) {
  try {
    JSON.parse(fs.readFileSync(file, "utf8"));
    console.log(`✓ ${file}`);
  } catch (err) {
    console.error(`✗ ${file} - ${err.message}`);
    failures++;
  }
}

if (failures > 0) {
  console.error(`\n❌ ${failures} invalid JSON file(s)`);
  process.exit(1);
} else {
  console.log(`\n✅ All ${files.length} JSON files valid`);
}
