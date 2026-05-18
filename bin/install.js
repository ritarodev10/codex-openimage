#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const c = {
  reset: '\x1b[0m',
  dim: '\x1b[2m',
  bold: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
};

const log = (m) => process.stdout.write(m + '\n');
const err = (m) => process.stderr.write(m + '\n');

const args = process.argv.slice(2);
const positional = args.filter((a) => !a.startsWith('-'));
const flags = new Set(args.filter((a) => a.startsWith('-')));
const cmd = positional[0] || 'install';
const isProject = flags.has('--project') || flags.has('-p');
const includeMissing = flags.has('--all');
const verbose = flags.has('--verbose') || flags.has('-v');

const HOME = os.homedir();
const CWD = process.cwd();
const SKILL_NAME = 'codex-openimage';
const SOURCE = path.resolve(__dirname, '..');

const XDG_DATA = process.env.XDG_DATA_HOME || path.join(HOME, '.local', 'share');
const TARGET = isProject
  ? path.join(CWD, '.codex-openimage')
  : path.join(XDG_DATA, SKILL_NAME);

function agentDirs() {
  if (isProject) {
    return [
      { name: 'Claude Code (project)', dir: path.join(CWD, '.claude', 'skills'), parent: path.join(CWD, '.claude') },
      { name: 'OpenCode (project)',    dir: path.join(CWD, '.opencode', 'skills'), parent: path.join(CWD, '.opencode') },
      { name: 'Pi (project)',          dir: path.join(CWD, '.pi', 'skills'), parent: path.join(CWD, '.pi') },
    ];
  }
  return [
    { name: 'Claude Code',    dir: path.join(HOME, '.claude', 'skills'),                  parent: path.join(HOME, '.claude') },
    { name: 'OpenCode',       dir: path.join(HOME, '.config', 'opencode', 'skills'),      parent: path.join(HOME, '.config', 'opencode') },
    { name: 'Pi',             dir: path.join(HOME, '.pi', 'agent', 'skills'),             parent: path.join(HOME, '.pi') },
    { name: 'skills-manager', dir: path.join(HOME, '.skills-manager', 'skills'),          parent: path.join(HOME, '.skills-manager') },
  ];
}

function exists(p) {
  try { fs.accessSync(p); return true; } catch { return false; }
}

function isSymlink(p) {
  try { return fs.lstatSync(p).isSymbolicLink(); } catch { return false; }
}

function readlinkSafe(p) {
  try { return fs.readlinkSync(p); } catch { return null; }
}

const SKIP_NAMES = new Set(['bin', 'node_modules', 'package.json', 'package-lock.json']);

function copyDirRecursive(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const item of fs.readdirSync(src, { withFileTypes: true })) {
    if (SKIP_NAMES.has(item.name) || item.name.startsWith('.')) continue;
    const s = path.join(src, item.name);
    const d = path.join(dst, item.name);
    if (item.isDirectory()) copyDirRecursive(s, d);
    else if (item.isSymbolicLink()) fs.symlinkSync(fs.readlinkSync(s), d);
    else fs.copyFileSync(s, d);
  }
}

function placeSource() {
  if (exists(TARGET)) {
    if (verbose) log(`${c.dim}~ replacing existing ${TARGET}${c.reset}`);
    fs.rmSync(TARGET, { recursive: true, force: true });
  }
  log(`${c.cyan}→ placing skill at ${c.bold}${TARGET}${c.reset}`);
  copyDirRecursive(SOURCE, TARGET);
}

function detectAndLink() {
  const linked = [];
  const skipped = [];
  for (const agent of agentDirs()) {
    const linkPath = path.join(agent.dir, SKILL_NAME);
    const parentExists = exists(agent.parent);
    if (!parentExists && !includeMissing) {
      skipped.push(agent);
      continue;
    }
    fs.mkdirSync(agent.dir, { recursive: true });
    if (isSymlink(linkPath)) {
      fs.unlinkSync(linkPath);
    } else if (exists(linkPath)) {
      fs.rmSync(linkPath, { recursive: true, force: true });
    }
    fs.symlinkSync(TARGET, linkPath, 'dir');
    linked.push({ ...agent, linkPath });
  }
  return { linked, skipped };
}

function unlinkOnly() {
  let count = 0;
  for (const agent of agentDirs()) {
    const linkPath = path.join(agent.dir, SKILL_NAME);
    if (isSymlink(linkPath) || exists(linkPath)) {
      const target = readlinkSafe(linkPath);
      fs.rmSync(linkPath, { recursive: true, force: true });
      log(`  ${c.green}✓${c.reset} ${agent.name} ${c.dim}(${linkPath}${target ? ' → ' + target : ''})${c.reset}`);
      count++;
    }
  }
  return count;
}

function install() {
  log('');
  log(`${c.bold}codex-openimage installer${c.reset}`);
  log(`${c.dim}scope: ${isProject ? 'project (current dir)' : 'user ($HOME)'}${c.reset}`);
  log('');

  placeSource();
  const { linked, skipped } = detectAndLink();

  log('');
  if (linked.length === 0) {
    log(`${c.yellow}No agent skill dirs found.${c.reset}`);
    log(`${c.dim}Skill files are placed at ${TARGET}, but no agents were detected to symlink into.${c.reset}`);
    log(`${c.dim}Install one of: Claude Code, OpenCode, Pi — or re-run with ${c.bold}--all${c.reset}${c.dim} to create the dirs anyway.${c.reset}`);
  } else {
    log(`${c.green}Linked into ${linked.length} agent${linked.length > 1 ? 's' : ''}:${c.reset}`);
    for (const a of linked) {
      log(`  ${c.green}✓${c.reset} ${a.name} ${c.dim}→ ${a.linkPath}${c.reset}`);
    }
  }

  if (skipped.length && verbose) {
    log('');
    log(`${c.dim}Skipped (agent not installed):${c.reset}`);
    for (const s of skipped) log(`  ${c.dim}· ${s.name}${c.reset}`);
  }

  log('');
  log(`${c.dim}Restart your agent (or run its skill-refresh) to pick up the new skill.${c.reset}`);
  log(`${c.dim}Update:    re-run ${c.reset}npx codex-openimage`);
  log(`${c.dim}Uninstall: ${c.reset}npx codex-openimage uninstall`);
  log('');
}

function uninstall() {
  log('');
  log(`${c.bold}codex-openimage uninstaller${c.reset}`);
  log(`${c.dim}scope: ${isProject ? 'project (current dir)' : 'user ($HOME)'}${c.reset}`);
  log('');

  const removed = unlinkOnly();
  if (exists(TARGET)) {
    fs.rmSync(TARGET, { recursive: true, force: true });
    log(`  ${c.green}✓${c.reset} removed source at ${c.dim}${TARGET}${c.reset}`);
  }

  log('');
  log(removed ? `${c.green}Done.${c.reset}` : `${c.dim}Nothing to remove.${c.reset}`);
  log('');
}

function help() {
  log('');
  log(`${c.bold}codex-openimage${c.reset} — bring OpenAI image gen to any AI coding agent`);
  log('');
  log(`${c.bold}Usage:${c.reset}`);
  log(`  npx codex-openimage                  install for the current user (default)`);
  log(`  npx codex-openimage --project        install scoped to the current project`);
  log(`  npx codex-openimage --all            create agent dirs even if agent isn't installed`);
  log(`  npx codex-openimage uninstall        remove symlinks + source files`);
  log(`  npx codex-openimage --help           this message`);
  log('');
  log(`${c.bold}Resolved paths for this invocation:${c.reset}`);
  log(`  source: ${c.dim}${SOURCE}${c.reset}`);
  log(`  target: ${c.dim}${TARGET}${c.reset}`);
  log(`  agent dirs probed:`);
  for (const a of agentDirs()) {
    log(`    · ${a.name}: ${c.dim}${a.dir}${c.reset}`);
  }
  log('');
}

function main() {
  if (flags.has('--help') || flags.has('-h') || cmd === 'help') return help();
  if (cmd === 'uninstall' || cmd === 'remove') return uninstall();
  if (cmd === 'install') return install();
  err(`${c.red}Unknown command: ${cmd}${c.reset}`);
  help();
  process.exit(1);
}

try {
  main();
} catch (e) {
  err(`${c.red}Error:${c.reset} ${e.message}`);
  if (verbose && e.stack) err(e.stack);
  process.exit(1);
}
