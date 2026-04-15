/**
 * Workspace index — lazily discovers and caches agents, skills, and instructions.
 */

import fs from "node:fs";
import path from "node:path";
import { parseFrontmatter } from "./parse-frontmatter.mjs";
import {
  AGENTS_DIR,
  SUBAGENTS_DIR,
  SKILLS_DIR,
  INSTRUCTIONS_DIR,
} from "./paths.mjs";

const ROOT = process.cwd();

// ─── Agents ──────────────────────────────────────────────────────────────────

let _agents = null;

/**
 * Returns Map<filename, AgentEntry>.
 * filename = "02-requirements.agent.md"
 */
export function getAgents() {
  if (_agents) return _agents;
  _agents = new Map();

  function scanDir(dir, isSubagent) {
    const absDir = path.resolve(ROOT, dir);
    if (!fs.existsSync(absDir)) return;
    for (const entry of fs.readdirSync(absDir, { withFileTypes: true })) {
      if (!entry.isFile() || !entry.name.endsWith(".agent.md")) continue;
      const relPath = path.join(dir, entry.name);
      const content = fs.readFileSync(path.resolve(ROOT, relPath), "utf-8");
      _agents.set(entry.name, {
        path: relPath,
        content,
        frontmatter: parseFrontmatter(content),
        isSubagent,
      });
    }
  }

  scanDir(AGENTS_DIR, false);
  scanDir(SUBAGENTS_DIR, true);
  return _agents;
}

// ─── Skills ──────────────────────────────────────────────────────────────────

let _skills = null;

/**
 * Returns Map<skillName, SkillEntry>.
 * skillName = "azure-defaults"
 */
export function getSkills() {
  if (_skills) return _skills;
  _skills = new Map();

  const absDir = path.resolve(ROOT, SKILLS_DIR);
  if (!fs.existsSync(absDir)) return _skills;

  for (const entry of fs.readdirSync(absDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const skillDir = path.join(absDir, entry.name);
    const skillMd = path.join(skillDir, "SKILL.md");
    const refsDir = path.join(skillDir, "references");
    const hasRefs = fs.existsSync(refsDir);

    let content = null;
    let frontmatter = null;
    if (fs.existsSync(skillMd)) {
      content = fs.readFileSync(skillMd, "utf-8");
      frontmatter = parseFrontmatter(content);
    }

    let refFiles = [];
    if (hasRefs) {
      refFiles = fs.readdirSync(refsDir).filter((f) => !f.startsWith("."));
    }

    _skills.set(entry.name, {
      dir: skillDir,
      content,
      frontmatter,
      hasRefs,
      refFiles,
    });
  }

  return _skills;
}

// ─── Skill Names ─────────────────────────────────────────────────────────────

let _skillNames = null;

/** Returns Set<string> of skill directory names. */
export function getSkillNames() {
  if (_skillNames) return _skillNames;
  const absDir = path.resolve(ROOT, SKILLS_DIR);
  if (!fs.existsSync(absDir)) return new Set();
  _skillNames = new Set(
    fs
      .readdirSync(absDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name),
  );
  return _skillNames;
}

// ─── Instructions ────────────────────────────────────────────────────────────

let _instructions = null;

/**
 * Returns Map<filename, InstructionEntry>.
 * filename = "agent-authoring.instructions.md"
 */
export function getInstructions() {
  if (_instructions) return _instructions;
  _instructions = new Map();

  const absDir = path.resolve(ROOT, INSTRUCTIONS_DIR);
  if (!fs.existsSync(absDir)) return _instructions;

  for (const entry of fs.readdirSync(absDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".instructions.md")) continue;
    const relPath = path.join(INSTRUCTIONS_DIR, entry.name);
    const content = fs.readFileSync(path.resolve(ROOT, relPath), "utf-8");
    _instructions.set(entry.name, {
      path: relPath,
      content,
      frontmatter: parseFrontmatter(content),
    });
  }

  return _instructions;
}
