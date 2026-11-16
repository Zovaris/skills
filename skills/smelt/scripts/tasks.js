#!/usr/bin/env node
// Task files shared by smelt and warden: one Markdown file per task in a task dir.
//   tasks.js list  [dir]                 table of tasks with status
//   tasks.js next  [dir]                 path of the first todo task whose blockers are done (exit 3 if none)
//   tasks.js ready [dir]                 every todo task whose blockers are done, one path per line
//   tasks.js set   <file> key=value...   update header lines (Status, PR, Owner...), add missing ones
//   tasks.js where                       print the task dirs found for this repo
//   tasks.js add   [dir] "<title>" [--blocked-by 01,02] [--key PROJ-12]   next NN file, prints its path
//   tasks.js board [--all]               one line per task list (and warden batch): this repo, or every
//                                        repo this machine has used (index in ~/.smithy/tasks-index.json)
// A task file starts with `# NN · <title>` followed by `Key: value` header lines:
//   Status: todo | doing | done | dropped     Blocked by: 01, 03 | none     PR: <url> | -
// Task dirs: docs/specs/<slug>/ (committed), .docs/specs/<slug>/ (in the repo, never committed),
// ~/.smithy/plans/<repo>/<slug>/ ($SMELT_PLANS), plus any colon-separated $SMELT_TASKS_DIRS.
// [dir] defaults to the only task dir found, else the most recently changed one.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const STATUSES = ['todo', 'doing', 'done', 'dropped'];
const die = (m, code = 1) => { process.stderr.write(m + '\n'); process.exit(code); };
const isTask = (f) => /^\d{2,}-.*\.md$/.test(f);

const repoRoot = () => { try { return execSync('git rev-parse --show-toplevel', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch { return process.cwd(); } };
const plansHome = () => process.env.SMELT_PLANS || path.join(process.env.SMITHY_HOME || path.join(os.homedir(), '.smithy'), 'plans');

const taskDirs = () => {
  const root = repoRoot();
  const extra = (process.env.SMELT_TASKS_DIRS || '').split(':').filter(Boolean).map((d) => path.resolve(root, d));
  const bases = [path.join(root, 'docs', 'specs'), path.join(root, '.docs', 'specs'), path.join(plansHome(), path.basename(root)), ...extra];
  const dirs = [];
  for (const b of bases) {
    if (!fs.existsSync(b)) continue;
    for (const d of fs.readdirSync(b)) {
      const full = path.join(b, d);
      if (fs.statSync(full).isDirectory() && fs.readdirSync(full).some(isTask)) dirs.push(full);
    }
  }
  return dirs.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
};

const resolveDir = (dir) => {
  if (dir) { if (!fs.existsSync(dir)) die(`no task dir ${dir}`); return path.resolve(dir); }
  const dirs = taskDirs();
  if (!dirs.length) die('no task dir found (docs/specs/, .docs/specs/, ~/.smithy/plans/<repo>/ or $SMELT_TASKS_DIRS); pass one');
  return dirs[0];
};

const parse = (file) => {
  const text = fs.readFileSync(file, 'utf8');
  const lines = text.split('\n');
  const title = (lines.find((l) => l.startsWith('# ')) || '').replace(/^#\s*/, '').replace(/^\d+\s*·\s*/, '');
  const head = {};
  for (const l of lines.slice(1, 15)) {
    const m = /^([A-Z][A-Za-z ]+):\s*(.*)$/.exec(l);
    if (m) head[m[1].toLowerCase()] = m[2].trim();
    else if (l.startsWith('## ')) break;
  }
  const nn = path.basename(file).match(/^(\d+)/)[1];
  const blockers = (head['blocked by'] || 'none').toLowerCase() === 'none' ? []
    : head['blocked by'].split(/[,\s]+/).filter(Boolean).map((b) => b.replace(/\D/g, '')).filter(Boolean);
  return { file, nn, title, status: (head.status || 'todo').toLowerCase(), blockers, pr: head.pr || '-' };
};

const smithyHome = () => process.env.SMITHY_HOME || path.join(os.homedir(), '.smithy');
const indexFile = () => path.join(smithyHome(), 'tasks-index.json');
const readIndex = () => { try { return JSON.parse(fs.readFileSync(indexFile(), 'utf8')); } catch { return {}; } };
// Remember every task dir we touch, so `board --all` can find lists in any repo without a tracker.
const remember = (dir) => {
  try {
    const idx = readIndex(); const abs = path.resolve(dir);
    if (idx[abs]) return;
    idx[abs] = { repo: path.basename(repoRoot()), seen: new Date().toISOString() };
    fs.mkdirSync(smithyHome(), { recursive: true }); fs.writeFileSync(indexFile(), JSON.stringify(idx, null, 1));
  } catch { /* the index is a convenience; never fail a command over it */ }
};

const load = (dir) => { remember(dir); return fs.readdirSync(dir).filter(isTask).sort().map((f) => parse(path.join(dir, f))); };

const add = (dir, title, { blockedBy = 'none', key = '' } = {}) => {
  fs.mkdirSync(dir, { recursive: true });
  const nums = fs.readdirSync(dir).filter(isTask).map((f) => Number(f.match(/^(\d+)/)[1]));
  const nn = String((nums.length ? Math.max(...nums) : 0) + 1).padStart(2, '0');
  const slug = title.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40).replace(/-[^-]*$/, (m) => (m.length > 1 ? m : ''));
  const file = path.join(dir, `${nn}-${slug || 'task'}.md`);
  const spec = fs.existsSync(path.join(dir, 'spec.md')) ? 'Spec: ./spec.md\n' : '';
  fs.writeFileSync(file, `# ${nn} · ${title}\nStatus: todo\nBlocked by: ${blockedBy}\nPR: -\n${key ? `Key: ${key}\n` : ''}${spec}\n## What\n\n## Acceptance criteria\n- [ ] \n`);
  remember(dir);
  return file;
};

const summary = (dir) => {
  const tasks = fs.readdirSync(dir).filter(isTask).sort().map((f) => parse(path.join(dir, f)));
  const n = (st) => tasks.filter((t) => t.status === st).length;
  return `${n('done')}/${tasks.length} done, ${n('doing')} doing, ${unblocked(tasks).length} ready`;
};

const board = (all) => {
  let dirs;
  if (all) {
    const idx = readIndex(); const live = {};
    for (const [d, v] of Object.entries(idx)) if (fs.existsSync(d) && fs.readdirSync(d).some(isTask)) live[d] = v;
    if (Object.keys(live).length !== Object.keys(idx).length) { try { fs.writeFileSync(indexFile(), JSON.stringify(live, null, 1)); } catch { /* read-only home */ } }
    for (const d of taskDirs()) if (!live[d]) live[d] = { repo: path.basename(repoRoot()) };
    dirs = Object.entries(live).map(([d, v]) => [d, v.repo]);
  } else dirs = taskDirs().map((d) => [d, path.basename(repoRoot())]);
  const out = dirs.sort((a, b) => a[1].localeCompare(b[1]) || a[0].localeCompare(b[0]))
    .map(([d, repo]) => `${`${repo}/${path.basename(d)}`.padEnd(36)}  ${summary(d).padEnd(34)}  ${d}`);
  const statusJs = path.join(__dirname, 'status.js');
  if (fs.existsSync(statusJs)) {
    const root = process.env.WARDEN_HOME || path.join(smithyHome(), 'warden');
    let batches = [];
    try { batches = fs.readdirSync(root).filter((b) => fs.existsSync(path.join(root, b, 'batch.json'))); } catch { /* none */ }
    for (const b of batches) {
      try {
        const items = JSON.parse(execSync(`node ${JSON.stringify(statusJs)} board ${JSON.stringify(b)} --json`, { stdio: ['ignore', 'pipe', 'ignore'] }).toString()).items || [];
        const counts = {}; for (const i of items) counts[i.stage] = (counts[i.stage] || 0) + 1;
        if (items.every((i) => ['merged', 'reported', 'dropped'].includes(i.stage)) && !all) continue;
        out.push(`${`batch ${b}`.padEnd(36)}  ${Object.entries(counts).map(([k, v]) => `${v} ${k}`).join(', ')}`);
      } catch { /* unreadable batch */ }
    }
  }
  return out;
};

const unblocked = (tasks) => {
  const done = new Set(tasks.filter((t) => t.status === 'done' || t.status === 'dropped').map((t) => Number(t.nn)));
  return tasks.filter((t) => t.status === 'todo' && t.blockers.every((b) => done.has(Number(b))));
};

const set = (file, pairs) => {
  if (!fs.existsSync(file)) die(`no task file ${file}`);
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  const h = lines.findIndex((l) => l.startsWith('# '));
  if (h < 0) die(`${file} has no '# NN · title' line`);
  for (const p of pairs) {
    const i = p.indexOf('=');
    if (i < 1) die(`not key=value: ${p}`);
    const key = p.slice(0, i).trim().replace(/^\w/, (c) => c.toUpperCase());
    const val = p.slice(i + 1).trim();
    if (key === 'Status' && !STATUSES.includes(val)) die(`Status must be one of ${STATUSES.join(', ')}`);
    let end = h + 1;
    while (end < lines.length && /^[A-Z][A-Za-z ]+:\s/.test(lines[end])) end++;
    const at = lines.slice(h + 1, end).findIndex((l) => l.toLowerCase().startsWith(key.toLowerCase() + ':'));
    if (at >= 0) lines[h + 1 + at] = `${key}: ${val}`; else lines.splice(end, 0, `${key}: ${val}`);
  }
  fs.writeFileSync(file, lines.join('\n'));
  return parse(file);
};

if (require.main === module) {
  const [cmd, ...a] = process.argv.slice(2);
  if (cmd === 'list') {
    const dir = resolveDir(a[0]); const tasks = load(dir);
    const rows = tasks.map((t) => [t.nn, t.status, t.blockers.join(',') || '-', t.pr, t.title]);
    const head = ['#', 'status', 'blocked by', 'pr', 'title'];
    const w = head.map((x, i) => Math.max(x.length, ...rows.map((r) => String(r[i]).length)));
    const line = (r) => r.map((c, i) => (i === r.length - 1 ? c : String(c).padEnd(w[i]))).join('  ');
    const n = (s) => tasks.filter((t) => t.status === s).length;
    console.log([dir, line(head), ...rows.map(line), `${n('done')}/${tasks.length} done, ${n('doing')} doing, ${unblocked(tasks).length} ready`].join('\n'));
  } else if (cmd === 'next') {
    const tasks = load(resolveDir(a[0])); const u = unblocked(tasks);
    if (u.length) console.log(u[0].file);
    else { console.error(tasks.every((t) => ['done', 'dropped'].includes(t.status)) ? 'all done' : 'nothing ready: the rest is doing or blocked'); process.exit(3); }
  } else if (cmd === 'ready') {
    const u = unblocked(load(resolveDir(a[0])));
    if (!u.length) process.exit(3);
    console.log(u.map((t) => t.file).join('\n'));
  } else if (cmd === 'set' && a.length >= 2) {
    console.log(JSON.stringify(set(a[0], a.slice(1))));
  } else if (cmd === 'add') {
    const flags = {}; const rest = [];
    for (let i = 0; i < a.length; i++) {
      if (a[i] === '--blocked-by') flags.blockedBy = a[++i];
      else if (a[i] === '--key') flags.key = a[++i];
      else rest.push(a[i]);
    }
    if (!rest.length) die('usage: tasks.js add [dir] "<title>" [--blocked-by 01,02] [--key K]', 2);
    const title = rest.pop(); const dir = rest[0] ? path.resolve(rest[0]) : resolveDir();
    console.log(add(dir, title, flags));
  } else if (cmd === 'board') {
    const lines = board(a.includes('--all'));
    if (!lines.length) { console.error('no task lists or batches yet'); process.exit(3); }
    console.log(lines.join('\n'));
  } else if (cmd === 'where') {
    const d = taskDirs(); if (!d.length) process.exit(3); console.log(d.join('\n'));
  } else die('Usage: tasks.js list [dir] | next [dir] | ready [dir] | set <file> key=value... | add [dir] "<title>" | board [--all] | where', 2);
}

module.exports = { load, parse, set, add, board, unblocked, taskDirs };
