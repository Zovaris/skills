#!/usr/bin/env node
// Zero-token waiter: blocks until one of the targets has an event, prints one line per event and
// exits, so an agent waiting on GitHub (or a warden batch) spends no tokens until there is work.
// Run it in the background where the harness wakes on exit, else in the foreground. Never
// replace it with sleep-then-check turns.
//
//   wait-for.js <target>... [--events e1,e2] [--all] [--every <sec>] [--max <min>]
//
// Targets (any mix, one call):
//   pr:<number|url>       checks finished (green/red), merged, closed, conflict, review, comment, push
//   run:<id|url>          a workflow run finished
//   branch:<name>         every workflow run on the branch's latest commit finished
//   prs[:<label>]         a PR opened or updated: yours, a warden batch's, or with the label
//   issues[:<label>]      an issue opened or updated with the label (default `agent`)
//   batch:<name>          a warden card needs the warden (needs warden's status.js beside this file)
//
// Output, one line each: `pr 42 checks=red failed=lint,unit <url>`, `pr 42 merged <url>`,
// `run 123 failure failed=build <url>`, `branch main success`, `pr 7 new <url>`,
// `issue 9 updated <url>`, `batch b1 <id>  <stage>  <phase>  <progress>  <text>`.
// pr checks already finished at start are reported at once, so a late call never hangs.
// Exit 0 = events printed, 4 = nothing within --max (heartbeat), 2 = usage, 3 = gh missing or signed out.
// Defaults come from settings watch.events, watch.every (30 s) and watch.max (50 min).
'use strict';
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ALL_EVENTS = ['checks', 'merged', 'closed', 'conflict', 'review', 'comment', 'push', 'new', 'updated'];
const die = (msg, code) => { console.error(msg); process.exit(code); };
const setting = (key, dflt) => {
  try { return execFileSync(path.join(__dirname, 'config.sh'), ['get', key], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim() || dflt; }
  catch { return dflt; }
};
const gh = (args) => JSON.parse(execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }) || 'null');
const ghText = (args) => execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
const smithyHome = () => process.env.SMITHY_HOME || path.join(os.homedir(), '.smithy');

// --- args
const argv = process.argv.slice(2);
const opt = { all: false };
const targets = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--all') opt.all = true;
  else if (a === '--events') opt.events = argv[++i];
  else if (a === '--every') opt.every = Number(argv[++i]);
  else if (a === '--max') opt.max = Number(argv[++i]);
  else if (a.startsWith('--')) die(`unknown option ${a}`, 2);
  else targets.push(a);
}
if (!targets.length) die('usage: wait-for.js <pr:N|run:ID|branch:NAME|prs[:label]|issues[:label]|batch:NAME>... [--events a,b] [--all] [--every s] [--max min]', 2);
const events = new Set(opt.all ? ALL_EVENTS : String(opt.events || setting('watch.events', ALL_EVENTS.join(','))).split(','));
const every = (Number.isFinite(opt.every) ? opt.every : Number(setting('watch.every', 30))) * 1000;
const maxMin = Number.isFinite(opt.max) ? opt.max : Number(setting('watch.max', 50));

// --- GitHub helpers
const repoOf = (url) => { const m = /github\.com\/([^/]+\/[^/]+)/.exec(url || ''); return m ? m[1] : null; };
const idOf = (s, re) => { const m = re.exec(s); return m ? m[1] : s; };
const checkSummary = (rollup) => {
  const runs = (rollup || []).map((c) => ({ name: c.name || c.context || '?', done: (c.status || 'COMPLETED') === 'COMPLETED' && c.state !== 'PENDING' && c.state !== 'EXPECTED', ok: ['SUCCESS', 'NEUTRAL', 'SKIPPED'].includes(c.conclusion || c.state) }));
  if (!runs.length) return { state: 'none' };
  if (runs.some((r) => !r.done)) return { state: 'pending' };
  const failed = runs.filter((r) => !r.ok).map((r) => r.name.replace(/\s+/g, '-'));
  return failed.length ? { state: 'red', failed } : { state: 'green' };
};

function prTarget(ref) {
  const repo = repoOf(ref);
  const num = idOf(ref, /\/pull\/(\d+)/);
  const args = ['pr', 'view', num, '--json', 'number,url,state,mergeable,reviewDecision,statusCheckRollup,headRefOid,comments,reviews'];
  if (repo) args.push('-R', repo);
  let last = null;
  const read = () => {
    const p = gh(args);
    return { url: p.url, num: p.number, state: p.state, mergeable: p.mergeable, review: p.reviewDecision || '', head: p.headRefOid,
      comments: (p.comments || []).length, reviews: (p.reviews || []).length, checks: checkSummary(p.statusCheckRollup) };
  };
  const checksLine = (s) => `pr ${s.num} checks=${s.checks.state}${s.checks.failed ? ` failed=${s.checks.failed.join(',')}` : ''} ${s.url}`;
  return {
    poll() {
      const s = read(); const out = [];
      if (!last) {
        last = s;
        if (s.state === 'MERGED' && events.has('merged')) out.push(`pr ${s.num} merged ${s.url}`);
        else if (s.state === 'CLOSED' && events.has('closed')) out.push(`pr ${s.num} closed ${s.url}`);
        else if (events.has('checks') && (s.checks.state === 'green' || s.checks.state === 'red')) out.push(checksLine(s));
        return out;
      }
      if (s.state !== last.state && s.state === 'MERGED' && events.has('merged')) out.push(`pr ${s.num} merged ${s.url}`);
      if (s.state !== last.state && s.state === 'CLOSED' && events.has('closed')) out.push(`pr ${s.num} closed ${s.url}`);
      if (s.head !== last.head && events.has('push')) out.push(`pr ${s.num} push head=${s.head.slice(0, 7)} ${s.url}`);
      const finished = s.checks.state === 'green' || s.checks.state === 'red';
      if (events.has('checks') && finished && (s.checks.state !== last.checks.state || s.head !== last.head)) out.push(checksLine(s));
      if (s.mergeable === 'CONFLICTING' && last.mergeable !== 'CONFLICTING' && events.has('conflict')) out.push(`pr ${s.num} conflict ${s.url}`);
      if ((s.reviews > last.reviews || s.review !== last.review) && events.has('review')) out.push(`pr ${s.num} review=${(s.review || 'commented').toLowerCase()} ${s.url}`);
      if (s.comments > last.comments && events.has('comment')) out.push(`pr ${s.num} comment +${s.comments - last.comments} ${s.url}`);
      last = s; return out;
    },
  };
}

function runTarget(ref) {
  const repo = repoOf(ref);
  const id = idOf(ref, /\/runs\/(\d+)/);
  const args = ['run', 'view', id, '--json', 'status,conclusion,name,url,jobs'];
  if (repo) args.push('-R', repo);
  return {
    poll() {
      const r = gh(args);
      if (r.status !== 'completed') return [];
      const failed = (r.jobs || []).filter((j) => j.conclusion && !['success', 'skipped', 'neutral'].includes(j.conclusion)).map((j) => j.name.replace(/\s+/g, '-'));
      return [`run ${id} ${r.conclusion}${failed.length ? ` failed=${failed.join(',')}` : ''} ${r.url}`];
    },
  };
}

function branchTarget(name) {
  return {
    poll() {
      const runs = gh(['run', 'list', '--branch', name, '--limit', '30', '--json', 'databaseId,status,conclusion,name,headSha,createdAt']) || [];
      if (!runs.length) return [];
      const sha = runs.slice().sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0].headSha;
      const latest = runs.filter((r) => r.headSha === sha);
      if (latest.some((r) => r.status !== 'completed')) return [];
      const failed = latest.filter((r) => !['success', 'skipped', 'neutral'].includes(r.conclusion)).map((r) => r.name.replace(/\s+/g, '-'));
      return [`branch ${name} ${failed.length ? 'failure' : 'success'}${failed.length ? ` failed=${failed.join(',')}` : ''} head=${sha.slice(0, 7)}`];
    },
  };
}

// prs / issues: new or updated since the last run of the same scope, remembered on disk.
function listTarget(kind, label) {
  const repo = ghText(['repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner']);
  const me = kind === 'pr' ? (() => { try { return ghText(['api', 'user', '-q', '.login']); } catch { return ''; } })() : '';
  const dir = process.env.TEND_HOME || path.join(smithyHome(), 'tend');
  const file = path.join(dir, `${repo.replace('/', '-')}-${kind === 'pr' ? 'prs' : 'issues'}${label ? `-${label}` : ''}.json`);
  const batchBranches = () => {
    const root = process.env.WARDEN_HOME || path.join(smithyHome(), 'warden');
    const out = new Set();
    try {
      for (const b of fs.readdirSync(root)) for (const f of fs.readdirSync(path.join(root, b))) {
        if (!f.endsWith('.json') || f === 'batch.json') continue;
        try { const c = JSON.parse(fs.readFileSync(path.join(root, b, f), 'utf8')); if (c.branch) out.add(c.branch); } catch { /* unreadable card */ }
      }
    } catch { /* no batches */ }
    return out;
  };
  const snapshot = () => {
    if (kind === 'pr') {
      const mine = batchBranches();
      return (gh(['pr', 'list', '--state', 'open', '--limit', '100', '--json', 'number,url,headRefName,author,labels,updatedAt']) || [])
        .filter((p) => (p.author && p.author.login === me) || mine.has(p.headRefName) || (label && (p.labels || []).some((l) => l.name === label)))
        .map((p) => ({ number: p.number, url: p.url, v: p.updatedAt }));
    }
    return (gh(['issue', 'list', '--state', 'open', '--limit', '100', '--label', label || 'agent', '--json', 'number,url,updatedAt']) || [])
      .map((i) => ({ number: i.number, url: i.url, v: i.updatedAt }));
  };
  let seen = null;
  try { seen = JSON.parse(fs.readFileSync(file, 'utf8')); } catch { /* first run */ }
  return {
    poll() {
      const now = snapshot();
      if (!seen) { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(file, JSON.stringify(now)); seen = now; return []; }
      const out = [];
      for (const n of now) {
        const o = seen.find((x) => x.number === n.number);
        if (!o && events.has('new')) out.push(`${kind} ${n.number} new ${n.url}`);
        else if (o && o.v !== n.v && events.has('updated')) out.push(`${kind} ${n.number} updated ${n.url}`);
      }
      if (out.length) { fs.writeFileSync(file, JSON.stringify(now)); seen = now; }
      return out;
    },
  };
}

// batch: warden cards. Wakes on stages that need the warden, or on any change with --all.
function batchTarget(name) {
  const statusJs = path.join(__dirname, 'status.js');
  if (!fs.existsSync(statusJs)) die('batch: targets need warden (status.js beside this script)', 2);
  const ACT = ['decide', 'stuck', 'verify', 'merged', 'reported', 'dropped'];
  const since = new Date().toISOString();
  const board = () => JSON.parse(execFileSync('node', [statusJs, 'board', name, '--json'], { encoding: 'utf8' })).items || [];
  const stuck = (items) => items.filter((i) => i.stage === 'stuck').map((i) => i.id).join(',');
  const stuckBefore = stuck(board());
  let reported = since;
  return {
    poll() {
      const items = board();
      const hits = items.filter((i) => i.updated && i.updated > reported && (opt.all || ACT.includes(i.stage)));
      if (hits.length) return hits.map((i) => `batch ${name} ${i.id}  ${i.stage}  ${i.phase || '-'}  ${i.progress || '-'}  ${i.text || ''}`);
      const s = stuck(items);
      return s && s !== stuckBefore ? [`batch ${name} stale: ${s}`] : [];
    },
  };
}

// --- main
const needsGh = targets.some((t) => !t.startsWith('batch:'));
if (needsGh) {
  try { execFileSync('gh', ['auth', 'status'], { stdio: 'ignore' }); }
  catch { die('gh is missing or signed out: install the GitHub CLI and run `gh auth login`', 3); }
}
const watchers = targets.map((t) => {
  const [kind, ...rest] = t.split(':'); const arg = rest.join(':');
  switch (kind) {
    case 'pr': return prTarget(arg);
    case 'run': return runTarget(arg);
    case 'branch': return branchTarget(arg);
    case 'prs': return listTarget('pr', arg);
    case 'issues': return listTarget('issue', arg);
    case 'batch': return batchTarget(arg);
    default: return die(`unknown target ${t}`, 2);
  }
});

const end = Date.now() + maxMin * 60 * 1000;
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
let first = true;
while (first || Date.now() < end) {
  const out = [];
  for (const w of watchers) {
    try { out.push(...w.poll()); } catch (e) {
      // A bad target fails on the first round: stop. Later errors are transient: try again next round.
      if (first) die(`cannot read target: ${String((e.stderr || e.message || '')).trim().split('\n')[0]}`, 2);
    }
  }
  if (out.length) { console.log(out.join('\n')); process.exit(0); }
  first = false;
  if (Date.now() + every > end) break;
  sleep(every);
}
console.log(`heartbeat: nothing within ${maxMin}m`);
process.exit(4);
