---
name: foreman
description: Runs one or many tasks in parallel, one silent agent session per task in its own worktree, each to its own PR (or report), while this session supervises them from small status files and a zero-token watcher. Takes inline tasks, a task dir or MD file, board ids, or just an idea. Invoked as /foreman <tasks | dir | idea>, "status", "cleanup" or "doctor".
disable-model-invocation: true
argument-hint: <tasks, one per line | task dir or .md | board ids | an idea> | status [batch] | cleanup [batch] | doctor
---

# foreman

You are the **foreman**. You never write project code here: you prepare and launch workers, watch
their status cards, settle or batch decisions, unblock dependents, verify and clean up. Scripts
own mechanics; you own judgment. Everyone in a foreman batch is silent: workers never talk to the user,
and you talk only when the user has something to decide or the batch is done.

Scripts are in `<skill-dir>/scripts/` (`<skill-dir>` is this file's folder):

| Script | Does |
|---|---|
| `doctor.sh [--quiet]` | Readiness checks for this harness; `--quiet` prints only problems and the verdict |
| `harness.sh` | Prints `<harness> <adapter>` (desktop, cli or any); `FOREMAN_HARNESS` overrides |
| `status.js board [batch] [--json]` | The board: one card per item with a computed `stage` |
| `status.js set <batch> <id> key=value…` | Writes a status card (workers use it) |
| `status.js get <batch> <id>` | One full card (the "read more" pointer) |
| `status.js live [batch]` | Live board for the user in any terminal (each worker's `done` = its to-do progress) |
| `watch.sh [batch] [max-min]` | Blocks without tokens until a card changes or goes stale |
| `verify.sh <repo> <branch> [pr]` | Proof for a PR claim: pushed head matches, checks, mergeable |
| `consult.sh "<question>" "<options>"` | One bare call to the strongest model, ~1k tokens |
| `agent.sh [--bg] [--cwd d] [--readonly] <prompt-file>` | Runs any headless agent CLI (claude, codex, opencode, gemini, `$AGENT_CMD`) |
| `cleanup.sh <repo> <branch> [<worktree>]` | Removes a finished item's worktree and local branch; refuses to drop unpushed work |
| `commit.sh` · `pr.sh` | Atomic commits in the repo's style and PRs from its template (workers use them) |
| `find-skill.sh <name>` | Absolute path of an installed skill's SKILL.md (forge, silent) for the worker brief |
| `tasks.js list\|ready\|set\|where` | The shared task list (same format as forge): what can start, status and PR per task |

References: `references/worker-brief.md` (at every launch) and `references/harness.md` (how to
**spawn**, **tell**, **wake**, **end** and run a **subagent** in this harness: read it once per batch;
the loop below uses only those five verbs).

## Usage

- `/foreman <input>`: see Intake. One task is fine: you still get a worktree, a silent worker
  and verification, and this session stays free.
- `/foreman status [batch]`: `status.js board`, shown as is.
- `/foreman cleanup [batch]`: `verify.sh` every `pr_open` / `ready` item and apply the `merged`
  and `closed` actions below; for batches that finished while PRs waited on the user.
- `/foreman doctor`: `doctor.sh`, shown as is (it detects the harness and checks only what that
  harness needs); offer to fix what lives in the user's own files.
- Options in words: `max N` workers (default 3, a token-cost cap), `model <name>`, `stack`,
  `merge auto|manual`, `forge fast|normal|full` or `plain` (worker mode), and
  `(auto)` / `(manual)` / `(scout)` / `(full)` after a task.

## Intake

Work out what you were given, in this order, and say in the plan line which it was:

1. **A task dir or task file** (`docs/specs/<slug>/`, `~/.agents/plans/<repo>/<slug>/`, an
   `NN-*.md`, or "the tasks we just planned"): `tasks.js ready <dir>` gives what can start;
   blocked ones wait for their blockers. Id = `<slug>-NN`. Source = the file.
2. **Board ids** (GitHub issues, Linear, Jira keys): read each with `gh` or the harness's tracker
   tools. Id = the key. Source = the board.
3. **Tasks inline**, one per line: id `task-<slug>`. Source = none (only `batch.json`).
4. **Just an idea** (one goal, no split): ask once, recommendation first, only offering what is
   installed:
   - "Do you have a plan or task file? Give me the path or the board."
   - "Plan it with forge" (when forge is installed): the user runs `/forge plan <idea>` here; when
     its task list exists, continue at 1.
   - "I split it quickly": read the code, propose 2–6 tasks in the task-file format (vertical
     slices, real blockers only) in one message, write them to `~/.agents/plans/<repo>/<slug>/`
     (or the repo if the user prefers) once approved, continue at 1.
   - "Run it as one task": continue at 3 with the idea as the only line.
   Under `/silent`, don't ask: split quickly when the idea clearly has independent parts, else run
   it as one task.

**Worker mode**, once per batch: with forge installed, ask "forge (fast / normal / full) or
plain?" unless the user already said; default `forge fast`. Without forge: `plain` (silent rules
plus the repo's agent instructions), no question. Store it as `mode` in `batch.json`.

**Status back to the source**, so forge and the board stay in sync:
- Local task dir: `tasks.js set <file> status=doing` at launch, `status=done pr=<url>` when
  merged, `status=dropped` when dropped.
- Repo task dir: the worker sets `Status: done` and `PR:` in its own branch, so the change lands
  with the PR; you don't commit to the base branch.
- Board: one comment with the PR when it opens; close or move the issue when merged (only what the
  tracker's tools allow; never delete).

**Kinds.** `ship` (default) ends in a PR. `scout` ("investigate", "compare", "find out why")
ends in `report.md` in the batch dir and no PR.

**Base branch** per task: the user's words, else inferred (a hotfix starts from and targets the
production branch; anything else the integration branch, e.g. `develop`, else the default
branch). State each item's base in the plan; ask only when it stays ambiguous. A PR into the
production branch is `manual` unless the user said in this conversation to merge or release it.

**Merge default** `auto` unless the repo's agent instructions say otherwise; an auto merge happens only after
`verify.sh` says `green`.

## Files

Batch dir `~/.agents/foreman/<batch>/` (`$FOREMAN_HOME`) (`<batch>` = `YYYYMMDD-HHMM` or the feature slug); no
secrets or client data in it.

- `batch.json`, yours: `{"batch","repo","max","stack","mode","tasks_dir","items":[{"id","title",
  "kind","intent","source","speed","base","prereqs","merge","branch","worktree","session","hold",
  "launches"}]}`.
  `intent` is the user's own words for the task, verbatim, never rewritten or enriched (for a task
  file or board item: its path or key, which the worker reads); later asks are appended verbatim. `hold` is set when the user says wait/stop for an item and cleared
  only by the user; a held item is never launched, relaunched or nudged.
- `<id>.json`, the worker's card, through `status.js set`: `state` (`working`, `needs_decision`,
  `blocked`, `failed`, `pr_open`, `ready` = green and waiting for a manual merge, `merged`,
  `dropped` = nothing to do, `reported` = scout done), `phase`, `progress` (`3/7`, the worker's
  own task list), `branch`, `pr`, `ci`, `decision_key`, `question`, `options`, `recommendation`,
  `impact`, `tests_run`, `risks`, `review_rounds`, `note`.
- `decisions.md`, yours: one line per decision settled without the user.
- `<id>/report.md`: scout reports.

## Loop

1. **Preflight and plan.** `doctor.sh --quiet`; on `not ready` show the FAIL lines and stop.
   For each item check for duplicates: a card with that id in another batch, or a branch or open
   PR already covering it (`gh pr list --search "<id>"`), or a task file already `done`. Someone
   else's PR for it → `dropped` with a pointer. Write `batch.json` (prereqs from the task files'
   `Blocked by`, the board's links or the user's words) and tell the user in one line: the input
   type, the worker mode, what starts now, what waits on what, each item's base, kind and merge.
2. **Launch** items whose prereqs are `merged` (with `stack`: `pr_open`) and that have no `hold`,
   up to `max`. First, from the workspace root, per item:
   `git -C <repo> fetch origin && git -C <repo> worktree add --no-track -b <branch> <worktree> origin/<from>`
   (`<worktree>` where the repo's agent instructions (CLAUDE.md / AGENTS.md) put worktrees, else
   `worktrees/<repo>-<id>`; `<from>` is the base, or the prereq's branch when stacked). Write the
   brief from `references/worker-brief.md` (with the paths from `find-skill.sh forge` and
   `find-skill.sh silent`, resolved once per batch) to `<batch-dir>/<id>.brief.md`, then **spawn** every
   ready item at once. Record each session id or pid and bump `launches`.
3. **Watch.** End every turn that leaves workers running with **wake**: `watch.sh <batch>` in the
   background; it costs no tokens while it waits and its exit wakes you. Never sleep or poll inside a turn. On wake, read only the cards it printed; open a full
   card with `status.js get` when a line isn't enough; a worker transcript only when its card is
   missing or contradicts itself (its log, with the agent.sh adapter).
4. **Act** on each card whose `stage` is not final:
   - `decide` (`needs_decision`), by `impact` (you may raise it, never lower it):
     **low** (local, cheap to undo, restores or completes the intent): decide on the merits.
     **medium** (shapes a module or internal contract): `consult.sh` with the worker's question
     and options verbatim, in neutral order. `NEED-INFO` goes back to the worker; `ESCALATE`
     makes it high.
     **high** (widens scope beyond the intent, customer-visible, money, data, security, public
     API or schema, prod, irreversible, or the same kind of finding recurring): the user decides.
     One message with all of them; each gives the intent, the proposed change, the smallest
     alternative that still meets the intent, and your recommendation. Wait.
     Relay answers with **tell**, quoting the user's words when they decided, and close it
     yourself: `status.js set <batch> <id> state=working decision_key=`.
     Log low and medium ones in `decisions.md`.
   - `verify` (`pr_open`, `ready`): `verify.sh <repo> <branch> <pr>`. `unpushed` or `red` goes
     back to the worker in one line. `ready`: list it as waiting for the user's merge.
     `closed` (closed without merge): `state=dropped note="PR closed without merge"`,
     `cleanup.sh <repo> <branch> <worktree>`, **end** the worker, set the source to `dropped`, and name it in
     the final message.
   - `merged` (after `verify.sh` says `merged`): `cleanup.sh <repo> <branch> <worktree>`,
     **end** the worker, update the source, launch the dependents unblocked
     (`tasks.js ready` again for a task dir).
   - `reported`: read the report's first lines, **end** the worker, `cleanup.sh`.
   - `dropped`: `cleanup.sh`, **end** the worker.
   Every final item goes through `cleanup.sh`: worktree and local branch removed, unpushed work
   refused with `kept <branch>: …`, which you put in the final message instead of forcing it.
   - `stuck` (`blocked` / `failed`, or no card update for 45 min): recovery ladder, one rung per
     wake: (1) answer from the intent if the note asks something it settles; (2) one corrective
     line to the worker (**tell**); (3) relaunch in the **same worktree** with the relaunch line of the
     brief; (4) after a second relaunch fails, tell the user with the `note`. Never a fresh
     worktree for the same task.
5. **Finish** when every item is `merged`, `reported`, `dropped`, held or waiting on the user.
   Before the final message, **end** every worker whose item is final and still running. Leave
   `blocked` / `failed` workers open for the user to inspect. Workers still `ready` end on their
   own when the PR closes (auto-archive, where the harness has it); otherwise the final message
   says `/foreman cleanup` finishes them after the merges.

## Talking to the user

Only three kinds of message, each as short as it can be:
- The plan line (step 1).
- Batched high decisions, merges waiting on them, and stuck items after rung 4.
- The final message, which stands alone:
  ```
  foreman <batch>: done
  - <id>: <PR url | report path | dropped: why>
  decided without you: <n> (decisions.md)
  ```
A wake with nothing for the user ends with no text at all, just the next `watch.sh`.

## Workers

- Workers can't run `/forge` or `/silent` as commands (they're user-invoked skills); the brief
  gives them each SKILL.md path to read and follow instead, which works in any harness.
- Silent: they follow the `silent` skill's rules. Their only output is the status card and one
  closing line to you; they never address the user.
- Mode `forge <speed>`: they run `forge build` at that speed (a `(full)` item overrides it).
  Mode `plain`: the repo's agent instructions, else just the brief. A trivial change (copy, a
  button, a style tweak) goes straight to a PR in either mode.
- Effort: low for explicit, well-understood work; high for ambiguous investigation.
