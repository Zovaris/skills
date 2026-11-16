# Changelog

One version for the whole repo, tagged `vX.Y.Z` (semver). Every change to a skill lands under
**Unreleased** first and moves into a version when it is tagged.

## Unreleased

### shared
- `agent.sh` runs workers unattended on every supported CLI, checked against each harness's docs and source: OpenCode `--standalone --auto` (tested live; without `--standalone` it doesn't work in the current folder), Codex with the git dir writable and network on, Gemini `--approval-mode yolo`, Claude `--permission-mode auto`, plus Cursor (`agent -p --force`), Pi (`pi -p`) and DeepSeek Harness (`dsh headless`). `AGENT_CLI` picks one, `AGENT_ARGS` adds flags. Workers get `FOREMAN_HARNESS` and lose the parent's harness variables; output goes through a file so a CLI that leaves a server running can't hang the caller.
- `harness.sh` detects Pi and DeepSeek Harness and no longer mistakes user settings (`CODEX_HOME`) for a harness; `find-skill.sh` and playbook's setup know every harness's skills folder and global instructions file.
- Codex: `agents/openai.yaml` keeps forge, foreman, silent and tend user-invoked.
- README: per-harness table (skills folder, how to start a skill, how workers run, background wake).

## v0.5.0 — 2026-11-15

### playbook (new)
- Loaded by the agent at the start of software work: lists the installed skills, routes work to them (forge, foreman, docs, scout, tend, silent, direct) and holds the shared rules and red flags.
- `scripts/setup.sh`: status of installed skills and models, and an opt-in pointer block for the user's `AGENTS.md` / `CLAUDE.md`.

### direct (new)
- Short, direct replies with no filler or AI tells; `silent` wins while it runs; code, commits, PRs and docs are written normally.

### docs (new)
- ADRs, glossary, module READMEs, codebase map, doc drift checks, comment policy (API doc comments only) and search over docs and decisions.

### scout (new)
- Read-only investigation with sources on the user's cheap model; reports recommend, never authorize.

### tend (new)
- Keeps open PRs mergeable: CI fixes, rebases after sibling merges, review comments; launched by foreman for its batches.
- Models: routine work on the user's cheap model, code fixes on the strong one; `--model` / `--fix-model` override.
- `watch [prs|issues|all]`: keeps adopting new PRs (default) and can queue accepted labeled issues as task files for foreman, never building them; `scripts/watch.sh` waits without tokens.
- A PR it can't get green comes back to foreman as a `blocked` / `needs_decision` card, or to the user as `needs you <url>: <why>`.

### forge
- `build all`: every task here with one implementer subagent each, per-task review, capped fix loop and a rulings ledger.
- Verify gate (no claim without fresh evidence) on build, test, review and ship; red-flag tables.
- Receiving review, a builder check after the spec, a security reviewer, Files and Interfaces in tasks, baseline test run, a three-way close (PR, merge if asked, keep).
- Delegates `adr`, `init`, context and the ship docs step to the docs skill when installed; fact-finding to scout.

### foreman
- Launches every worker in the user's turn; items that can't start yet wait in their own session on `wait-turn.sh` (new `waiting` state) until their prereqs merge and a slot frees. Batches with dependencies stay autonomous in harnesses that can't start sessions from event turns.
- The watcher wakes only for cards that need the foreman (decisions, stuck, PRs, merged, reported, dropped); `--all` for every change.
- Workers merge `origin/<base>` before opening the PR and before merging; a refused merge ends as `ready note=merge-blocked` and the foreman merges; work found after a merge becomes a follow-up PR (small) or a task file for the foreman to decide.
- `merge auto|manual` and `cleanup auto|ask`, both `auto` by default and stored in `batch.json`; worktrees default to a sibling `<repo-parent>/worktrees/<repo>-<id>`.
- `doctor` suggests allowing `gh pr merge` in Claude Code; `harness.md` documents the event-turn rule and finding a card's session id.
- Scout items follow the scout skill; a tend session keeps the batch's PRs green once workers end.
- Models come from the user's choice per harness (`config.sh`), never hard-coded; `consult.sh` uses the strong one.
- `doctor` checks the companion skills and model settings.

### shared
- Settings: `config.sh` reads `<repo>/.agents/config.json` then `~/.agents/config.json` then defaults; `config.sh list` shows every setting, its value and source; `set --repo` saves per repo. Known settings: models, `tasks.location/commit/ignore`, `foreman.merge/cleanup/max/mode`, `tend.watch/label`.
- `task-dir.sh <slug>`: one place that decides where specs and tasks go; asks `tasks.commit` once per repo and, when specs stay out of git, whether to add `.docs/` to `.gitignore` or `.git/info/exclude`.
- `tasks.js where` also finds `.docs/specs/` (specs kept out of git) and `$FORGE_TASKS_DIRS`; forge reads `tasks.location` / `tasks.commit` (default committed) from the user config.
- `config.sh` (cheap and strong model per harness in `~/.agents/config.json`), `find-skill.sh --list`; `harness.sh`, `verify.sh` moved to `shared/`.
- `tests/run.sh` (offline tests, skill lint) in CI, and `scripts/drill.sh` for live pressure tests against an agent CLI.

### forge and foreman
- `commit.sh`: detects the repo's commit style (commitlint, history: conventional, gitmoji or plain), checks messages and commits exactly the given paths, one concern per commit.
- `pr.sh`: finds the PR template and refuses a body that drops its headings; reuses an open PR instead of opening a second one.
- `cleanup.sh`: removes a finished task's worktree and local branch every time, and refuses to drop unpushed work.
- Shared scripts live in `shared/` and are copied into each skill by `scripts/sync-shared.sh`; CI checks they stay in sync.

### foreman
- Workers turn on their harness's auto-archive when their PR closes, so sessions waiting on a manual merge end on their own.
- A PR closed without merge marks the item `dropped` and ends its worker.
- The foreman ends every finished worker before its final message; `blocked` / `failed` ones stay open for inspection.
- New `/foreman cleanup [batch]`: re-verifies waiting PRs after the batch is over and ends their workers.

## v0.4.0 — 2026-11-15

First tagged release.

### silent
- Runs a task end to end with no talk between tool calls; progress only in the harness's to-do list.
- Ends with one line in English: `done: <where it landed>` (PR, commits, uncommitted changes or an answer); only commits or opens a PR when the task asks.
- Stops only for what is the user's alone, with `blocked: <why>`.

### forge
- Phases with exit gates: brainstorm (why, approaches, design) → grill → spec → task list → TDD → test agents → review → ship → retro.
- Start at any phase (`/forge build`, `/forge test`, `/forge from test`) at three speeds: `fast`, `normal`, `full`.
- Shared task list (`NN-<slug>.md` with `Status`, `Blocked by`, `PR`) on a board, in the repo or in `~/.agents/plans`, managed by `scripts/tasks.js`; `/forge build next` works it one task at a time.
- Independent test agents: adversary, regression, property, mutation, E2E; read-only spec-check and standards reviewers.
- ADRs, glossary and standards docs; optional `guard-tests.sh` pre-edit hook.

### foreman
- Runs one or many tasks in parallel: one silent worker and git worktree per task, each to a PR or a report.
- Takes inline tasks, a task dir, board ids or just an idea (offers to plan it with forge or split it).
- Workers follow forge (`fast` / `normal` / `full`) or plain mode, reading each skill's `SKILL.md` by path.
- Status cards, a zero-token watcher, PR verification, decisions escalated by impact, recovery ladder.
- Harness-agnostic: adapters for Claude Code desktop and CLI, and `agent.sh` for any agent CLI; `doctor` checks only what the detected harness needs.
