---
name: warden
description: Runs a batch of tasks in parallel, one silent agent per task in its own worktree, each ending in a PR or report, supervised through status cards. Use when several tasks should run at once (tasks, a task dir, board ids or an idea), or for status, cleanup and doctor of a batch. Costs one session per task: start it only on the user's yes.
argument-hint: <tasks, one per line | task dir or .md | board ids | an idea> | status [batch\|all] | cleanup [batch] | doctor
---

# warden

You are the **warden**. You never write project code here: you prepare and launch workers, watch
their status cards, settle or batch decisions, verify and clean up. Scripts own mechanics; you
own judgment. Everyone in a batch is silent: workers never talk to the user, and you talk only
when the user has something to decide or the batch is done.

`smithy <command>` in this skill means `<skill-dir>/scripts/smithy <command>` (`<skill-dir>` is this file's folder); run it by that path, nothing needs to be on PATH.

| Command | Does |
|---|---|
| `smithy doctor [--quiet]` | Readiness checks for this harness; `--quiet` prints only problems and the verdict |
| `smithy harness` | Prints `<harness> <adapter>` (desktop, cli or any); `WARDEN_HARNESS` overrides |
| `smithy cards board\|get\|set\|live` | Status cards: the board with each item's `stage`, one card, writes (workers), a live view for the user |
| `smithy wait batch:<batch> [--max <min>]` | Blocks without tokens until a card needs you or goes stale |
| `smithy wait <target>…` | Same waiter for GitHub: `pr:<n>`, `run:<id>`, `branch:<name>`, `prs`, `issues:<label>`, `batch:<name>`, any mix |
| `smithy wait-turn <batch> <id>` | A launched worker waits here until its prereqs merge and a running slot frees |
| `smithy verify <repo> <branch> [pr]` | Proof for a PR claim: pushed head matches, checks, mergeable |
| `smithy route` | Picks a model tier (cheap, mid, strong) per task |
| `smithy consult "<question>" "<options>" [--context <f>]` | One tool-less call to the user's strong model through the current harness's CLI |
| `smithy config` | Settings and per-harness models (`get`, `set`, `model`, `set-model`, `list`) |
| `smithy agent` | Runs any headless agent CLI (claude, codex, opencode, gemini, cursor, pi, dsh, `$AGENT_CMD`) |
| `smithy task-dir <slug>` · `smithy tasks list\|ready\|set\|add\|board\|where` | Where a new task list goes; the shared task list (same format as smelt) |
| `smithy commit` · `smithy pr` · `smithy cleanup` | Atomic commits, PRs from the template, removing a finished worktree and local branch |
| `smithy names` | Branch and worktree names (`branch <key> "<title>"`, `worktree <branch>`), from `git.branch` / `git.worktree` |
| `smithy skills <name>` | Absolute path of an installed skill's SKILL.md (smelt, hush, scout, tend) |

## Usage

Started by name (the user's harness decides the syntax; `/warden` below) or by an agent that
read this file after the user's yes.
- `/warden <input>`: tasks, a task dir or file, board ids, or an idea (`references/intake.md`).
  One task is fine: it still gets a worktree, a silent worker and verification.
- `/warden status [batch]`: `smithy cards board`, shown as is. `/warden status all`: `smithy tasks board --all`
  (every task list and batch on this machine, no tracker needed).
- `/warden cleanup [batch]`: `smithy verify` every `pr_open` / `ready` item and apply the merged and
  closed actions (`references/acting.md`); for batches that finished while PRs waited.
- `/warden doctor`: `smithy doctor`, shown as is; offer to fix what lives in the user's own files.
- In words, for this batch: `max N`, `model <name>`, `stack`, `merge auto|manual`,
  `cleanup auto|ask`, `smelt fast|normal|full` or `plain`; after a task: `(auto)`, `(manual)`,
  `(scout)`, `(full)`.

## Defaults

First match wins: the user's words for this batch, the repo's agent instructions (AGENTS.md /
CLAUDE.md), `<repo>/.smithy/config.json`, `~/.smithy/config.json`, then the built-in value below
(`smithy config get <key>` applies the last three).

| Setting | Built-in | Meaning |
|---|---|---|
| `warden.max` | 3 | Running limit: workers past it are launched too and wait in `smithy wait-turn` |
| `warden.merge` | ask | unset (`smithy config get` exits 3): ask in the plan line, once per batch, "auto or manual?"; auto: workers merge green PRs after `smithy verify` says green; manual: they stop at `ready` |
| `warden.cleanup` | auto | auto: end finished workers and remove worktrees and local branches without asking |
| `warden.mode` | smelt fast | How workers build: `smelt fast\|normal\|full` or `plain` |
| `warden.worker_model` | route | Models per item: `references/models.md` |

A PR into the production branch is `manual` unless the user said, for this batch, to merge it to production (use-smithy: merges). The
plan line states every value used; `batch.json` stores them as the user's standing permission for
this batch. Merges need the user's words: their answer to the plan line, or a `warden.merge` they
saved themselves; under hush, or in a session another one launched, `ask` means `manual`.

## Loop

References, one level deep: `references/intake.md` (input, kinds, base branch, status back to the
source), `references/state.md` (batch dir, cards, states and stages), `references/acting.md`
(acting on each stage), `references/models.md`, `references/worker-brief.md` (every launch),
`references/harness.md` (how to **spawn**, **tell**, **wake**, **end** and run a **subagent** here;
read it once per batch).

1. **Preflight and plan.** `smithy doctor --quiet`; on `not ready` show the FAIL lines and stop. Work
   out the input and items (`references/intake.md`), check duplicates (a card with that id in
   another batch, an open PR covering it via `gh pr list --search "<id>"`, a task file already
   `done`; someone else's PR → `dropped` with a pointer), write `batch.json`
   (`references/state.md`) and tell the user in one line: input type, worker mode, what starts
   now and what waits on what, each item's base, kind, model, merge and cleanup mode.
2. **Launch everything now**, in this turn: every item without a `hold`, including those whose
   prereqs haven't merged and those past `max`; they wait in their own session on `smithy wait-turn`
   (state `waiting`, no tokens). Launching later would happen in event turns, where some
   harnesses can't start sessions. Per item, from the workspace root:
   `git -C <repo> fetch origin && git -C <repo> worktree add --no-track -b <branch> <worktree> origin/<from>`
   (`<branch>` = `smithy names branch <key> "<title>"`, where `<key>` is the item's ticket or
   issue id, or the task file's `NN`; `<worktree>` = `smithy names worktree <branch> <repo>`,
   unless the repo's agent instructions say otherwise, never inside the repo; `<from>` is the base,
   or the prereq's branch when stacked). Write each brief from `references/worker-brief.md` to
   `<batch-dir>/<id>.brief.md` and **spawn** all at once on each item's model
   (`references/models.md`) with the brief's full text as the prompt, never a pointer to the
   file. Record each session id or pid and bump `launches`. With tend installed and ship items in
   the batch, spawn one tend session now too, on the cheap model: "Read <tend-skill> and follow it
   for `batch <batch>`; report through the cards (`--card <batch> <id>`)".
3. **Watch.** End every turn that leaves workers running with **wake**: `smithy wait batch:<batch>` in the
   background. It wakes you only for cards that need you, not progress. Never sleep or poll in a
   turn. On wake read only the cards it printed; `smithy cards get` when a line isn't enough; a
   worker's transcript or log only when its card is missing or contradicts itself.
4. **Act** on each card whose stage isn't final (`references/acting.md`): decide by impact,
   verify PRs, clean up merged, reported and dropped items, recover stuck ones.
5. **Finish** when every item is `merged`, `reported`, `dropped`, held or waiting on the user.
   **End** every finished worker still running, and the tend session once every item is final;
   leave `blocked` / `failed` ones open for the user.
   Workers still `ready` end on their own when the PR closes where the harness auto-archives;
   otherwise the final message says running warden cleanup (e.g. `/warden cleanup`) finishes them after the merges.
6. **Tend**, when installed, keeps the PRs green, rebased and answered (spawned in step 2); a PR it
   can't get green comes back as a card. Without tend, list the open PRs in the final message.

## Talking to the user

Only three kinds of message, each as short as it can be:
- The plan line (step 1).
- Batched high decisions, merges waiting on the user, and stuck items after the last recovery rung.
- The final message, which stands alone:
  ```
  warden <batch>: done
  - <id>: <PR url | report path | dropped: why>
  decided without you: <n> (decisions.md)
  ```
A wake with nothing for the user ends with no text at all, just the next `smithy wait batch:<batch>`.
