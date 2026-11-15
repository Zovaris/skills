#!/usr/bin/env node
// Status files for a foreman batch, so nobody hand-writes JSON.
//   status.js set <batch> <id> key=value...    merge into <id>.json (value parsed as JSON when it is JSON), stamps `updated`
//   status.js get <batch> <id>                 print one status file
//   status.js board [batch] [--changed-since <iso>] [--json]
//                                              one line per item with a computed stage; newest batch when omitted.
//                                              --changed-since exits 3 when nothing changed (for until-loops).
//   status.js live [batch] [--every 5]         redraws the board in a terminal for humans
// Files live in $FOREMAN_HOME (default ~/.agents/foreman)/<batch>/.
const fs = require('fs');
const os = require('os');
const path = require('path');

const HOME = process.env.FOREMAN_HOME || path.join(os.homedir(), '.agents', 'foreman');
const STATES = ['working', 'needs_decision', 'blocked', 'failed', 'pr_open', 'ready', 'merged', 'dropped', 'reported'];
const STALE_MIN = Number(process.env.FOREMAN_STALE_MIN || 45);
const read = (f) => { try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return null; } };
const die = (m, code = 1) => { process.stderr.write(m + '\n'); process.exit(code); };
const ID = /^[A-Za-z0-9._-]+$/;

const set = (batch, id, pairs) => {
  if (!ID.test(batch) || !ID.test(id)) die('batch and id must match [A-Za-z0-9._-]+');
  const dir = path.join(HOME, batch);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `${id}.json`);
  const cur = read(file) || { id };
  for (const p of pairs) {
    const i = p.indexOf('=');
    if (i < 1) die(`not key=value: ${p}`);
    const [k, raw] = [p.slice(0, i), p.slice(i + 1)];
    let v = raw;
    try { v = JSON.parse(raw); } catch { /* plain string */ }
    cur[k] = v === '' ? null : v;
  }
  if (cur.state && !STATES.includes(cur.state)) die(`state must be one of ${STATES.join(', ')}`);
  // A decision stays open until it is closed explicitly (state moves off needs_decision with decision_key cleared).
  if (cur.state !== 'needs_decision' && cur.decision_key && !pairs.some((p) => p.startsWith('decision_key='))) {
    die(`decision ${cur.decision_key} is still open; the foreman closes it with decision_key=`);
  }
  if (cur.state !== 'needs_decision' && pairs.includes('decision_key=')) {
    for (const k of ['decision_key', 'question', 'options', 'recommendation', 'impact']) delete cur[k];
  }
  if (cur.state === 'needs_decision') {
    for (const k of ['decision_key', 'question', 'impact']) if (!cur[k]) die(`needs_decision requires ${k}`);
    if (!['low', 'medium', 'high'].includes(cur.impact)) die('impact must be low, medium or high');
  }
  const tmp = `${file}.${process.pid}.tmp`;
  cur.updated = new Date().toISOString();
  fs.writeFileSync(tmp, JSON.stringify(cur, null, 2) + '\n');
  fs.renameSync(tmp, file); // atomic: the foreman never reads a half-written file
  return cur;
};

// First match wins: what the foreman has to do with this item now.
const stage = (s, item) => {
  if (item.hold) return 'held';
  if (!s) return item.session ? 'starting' : 'queued';
  const age = s.updated ? (Date.now() - Date.parse(s.updated)) / 60000 : 0;
  switch (s.state) {
    case 'needs_decision': return 'decide';
    case 'blocked': case 'failed': return 'stuck';
    case 'pr_open': case 'ready': return 'verify';
    case 'merged': return 'merged';
    case 'reported': return 'reported';
    case 'dropped': return 'dropped';
    default: return age > STALE_MIN ? 'stuck' : 'working';
  }
};

const latestBatch = () => {
  const all = fs.existsSync(HOME) ? fs.readdirSync(HOME).filter((d) => fs.statSync(path.join(HOME, d)).isDirectory()) : [];
  const b = all.sort((x, y) => fs.statSync(path.join(HOME, y)).mtimeMs - fs.statSync(path.join(HOME, x)).mtimeMs)[0];
  if (!b) die(`no batches in ${HOME}`);
  return b;
};

const rowsFor = (batch) => {
  const dir = path.join(HOME, batch);
  if (!fs.existsSync(dir)) die(`no batch ${batch} in ${HOME}`);
  const plan = read(path.join(dir, 'batch.json')) || { items: [] };
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.json') && f !== 'batch.json').map((f) => f.slice(0, -5));
  const ids = [...new Set([...plan.items.map((i) => i.id), ...files])];
  return ids.map((id) => {
    const s = read(path.join(dir, `${id}.json`));
    const item = plan.items.find((i) => i.id === id) || {};
    const age = s?.updated ? Math.round((Date.now() - Date.parse(s.updated)) / 60000) : null;
    return { id, stage: stage(s, item), state: s?.state || '-', phase: s?.phase || '-', progress: s?.progress || '-', pr: s?.pr || '-', ci: s?.ci || '-',
      age: age === null ? '-' : `${age}m`, updated: s?.updated || null,
      text: item.hold ? `hold: ${item.hold}` : (s?.question || s?.note || '') };
  });
};

const board = (batch, { since, json } = {}) => {
  batch = batch || latestBatch();
  const rows = rowsFor(batch);
  if (since && !rows.some((r) => r.updated && r.updated > since)) process.exit(3);
  if (json) return JSON.stringify({ batch, items: rows }, null, 2);
  const cols = ['id', 'stage', 'state', 'phase', 'progress', 'pr', 'ci', 'age', 'text'];
  const head = ['item', 'stage', 'state', 'phase', 'done', 'pr', 'ci', 'age', 'question / note'];
  const table = rows.map((r) => cols.map((c) => String(r[c])));
  const w = head.map((h, i) => Math.max(h.length, ...table.map((r) => r[i].length)));
  const line = (r) => r.map((c, i) => (i === r.length - 1 ? c : c.padEnd(w[i]))).join('  ');
  return [`batch ${batch}`, line(head), ...table.map(line)].join('\n');
};

if (require.main === module) {
  const argv = process.argv.slice(2);
  const cmd = argv.shift();
  const flag = (name) => { const i = argv.indexOf(name); if (i < 0) return undefined; const v = argv[i + 1]; argv.splice(i, 2); return v; };
  if (cmd === 'set' && argv.length >= 3) console.log(JSON.stringify(set(argv[0], argv[1], argv.slice(2))));
  else if (cmd === 'get' && argv.length === 2) console.log(JSON.stringify(read(path.join(HOME, argv[0], `${argv[1]}.json`)), null, 2));
  else if (cmd === 'board') {
    const json = argv.includes('--json'); if (json) argv.splice(argv.indexOf('--json'), 1);
    const since = flag('--changed-since');
    console.log(board(argv[0], { since, json }));
  } else if (cmd === 'live') {
    // Human view for any terminal: redraws the board every few seconds until Ctrl-C.
    const every = Number(flag('--every') || 5) * 1000;
    const draw = () => { process.stdout.write('\x1b[2J\x1b[H' + board(argv[0]) + `\n\n(every ${every / 1000}s, Ctrl-C to quit)\n`); };
    draw(); setInterval(draw, every);
  } else die('Usage: status.js set <batch> <id> key=value... | get <batch> <id> | board [batch] [--changed-since <iso>] [--json] | live [batch] [--every s]', 2);
}

module.exports = { set, board, stage, STATES };
