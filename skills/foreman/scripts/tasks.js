#!/usr/bin/env node
// Task files shared by forge and foreman: one Markdown file per task in a task dir.
//   tasks.js list  [dir]                 table of tasks with status
//   tasks.js next  [dir]                 path of the first todo task whose blockers are done (exit 3 if none)
//   tasks.js ready [dir]                 every todo task whose blockers are done, one path per line
//   tasks.js set   <file> key=value...   update header lines (Status, PR, Owner...), add missing ones
//   tasks.js where                       print the task dirs found for this repo
// A task file starts with `# NN · <title>` followed by `Key: value` header lines:
//   Status: todo | doing | done | dropped     Blocked by: 01, 03 | none     PR: <url> | -
// Task dirs: docs/specs/<slug>/ (committed), .docs/specs/<slug>/ (in the repo, never committed),
// ~/.agents/plans/<repo>/<slug>/ ($FORGE_PLANS), plus any colon-separated $FORGE_TASKS_DIRS.
// [dir] defaults to the only task dir found, else the most recently changed one.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const STATUSES = ['todo', 'doing', 'done', 'dropped'];
const die = (m, code = 1) => { process.stderr.write(m + '\n'); process.exit(code); };
const isTask = (f) => /^\d{2,}-.*\.md$/.test(f);

const repoRoot = () => { try { return execSync('git rev-parse --show-toplevel', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch { return process.cwd(); } };
const plansHome = () => process.env.FORGE_PLANS || path.join(os.homedir(), '.agents', 'plans');

const taskDirs = () => {
  const root = repoRoot();
  const extra = (process.env.FORGE_TASKS_DIRS || '').split(':').filter(Boolean).map((d) => path.resolve(root, d));
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
  if (!dirs.length) die('no task dir found (docs/specs/, .docs/specs/, ~/.agents/plans/<repo>/ or $FORGE_TASKS_DIRS); pass one');
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

const load = (dir) => fs.readdirSync(dir).filter(isTask).sort().map((f) => parse(path.join(dir, f)));

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
  } else if (cmd === 'where') {
    const d = taskDirs(); if (!d.length) process.exit(3); console.log(d.join('\n'));
  } else die('Usage: tasks.js list [dir] | next [dir] | ready [dir] | set <file> key=value... | where', 2);
}

module.exports = { load, parse, set, unblocked, taskDirs };
