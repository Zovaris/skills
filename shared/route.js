#!/usr/bin/env node
// Model router: picks the cheapest model tier that can do a task well, from the task itself.
//   route.js [--file <task.md>] [--text "<task words>"] [--kind ship|scout|review|fix|tend]
//            [--speed fast|normal|full] [--json]
// Prints `<tier> <model>  # reasons`, or JSON with --json. <model> is the user's model for that
// tier in this harness (smithy config model <tier>); `-` when unset (use the session default, and
// propose `smithy config suggest-models`, or ask the user to name the tier). The caller may move one tier up or down with a stated reason;
// a user's explicit model always wins.
// Tiers: cheap (mechanical, read-only, small), mid (most feature work), strong (risky, ambiguous,
// cross-cutting, or the last fix round).
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : undefined; };
const file = opt('--file');
let text = opt('--text') || '';
if (file) text += '\n' + fs.readFileSync(file, 'utf8');
const kind = opt('--kind') || 'ship';
const speed = opt('--speed') || 'normal';
if (!text.trim() && kind === 'ship') { process.stderr.write('route.js: give --file or --text\n'); process.exit(2); }

const low = text.toLowerCase();
const has = (words) => words.filter((w) => new RegExp(`\\b${w}`, 'i').test(low));
const RISK = ['auth', 'login', 'password', 'secret', 'token', 'permission', 'security', 'payment', 'billing', 'money', 'invoice', 'migration', 'schema', 'database', 'concurren', 'race condition', 'lock', 'crypto', 'encrypt', 'data loss', 'delete user', 'production', 'public api'];
const HARD = ['architecture', 'redesign', 'refactor', 'performance', 'investigate', 'root cause', 'why does', 'ambiguous', 'trade-off', 'cross-cutting', 'rewrite', 'remake', 'protocol', 'parser', 'compiler', 'algorithm'];
const TRIVIAL = ['typo', 'copy change', 'wording', 'rename', 'bump', 'version', 'color', 'colour', 'style tweak', 'readme', 'comment', 'lint', 'format'];

const criteria = (text.match(/^\s*- \[[ x]\]/gm) || []).length;
const files = (() => { const m = text.match(/## Files([\s\S]*?)(\n## |$)/); return m ? (m[1].match(/[\w./-]+\.\w+/g) || []).length : 0; })();
const interfaces = (() => { const m = text.match(/## Interfaces([\s\S]*?)(\n## |$)/); return m ? (m[1].match(/^\s*- /gm) || []).length : 0; })();

let score = 1; const reasons = [];
const risk = has(RISK), hard = has(HARD), trivial = has(TRIVIAL);
if (kind === 'scout' || kind === 'review' || kind === 'tend') { score = 0; reasons.push(`${kind} work`); }
if (risk.length) { score = 2; reasons.push(`risky: ${risk.slice(0, 3).join(', ')}`); }
if (hard.length && score < 2) { score += 1; reasons.push(`hard: ${hard.slice(0, 3).join(', ')}`); }
if (criteria > 6 || files > 8 || interfaces > 4) { score += 1; reasons.push(`large: ${criteria} criteria, ${files} files, ${interfaces} interfaces`); }
if (!risk.length && !hard.length && trivial.length && criteria <= 2 && files <= 2) { score -= 1; reasons.push(`small: ${trivial.slice(0, 2).join(', ')}`); }
if (speed === 'full') { score = Math.max(score, 2); reasons.push('speed full'); }
if (speed === 'fast' && !risk.length) { score = Math.min(score, 1); reasons.push('speed fast'); }
if (kind === 'fix') { score = Math.max(score, 1); reasons.push('code fix'); }
score = Math.max(0, Math.min(2, score));
if (!reasons.length) reasons.push('ordinary feature work');

const tier = ['cheap', 'mid', 'strong'][score];
let model = '';
try { model = execFileSync(path.join(__dirname, 'smithy'), ['config', 'model', tier], { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(); } catch { model = ''; }
if (args.includes('--json')) console.log(JSON.stringify({ tier, model: model || null, reasons }));
else console.log(`${tier} ${model || '-'}  # ${reasons.join('; ')}`);
