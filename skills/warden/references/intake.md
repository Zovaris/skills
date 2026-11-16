# Intake

## Input

Work out what you were given, in this order, and say in the plan line which it was:

1. **A task dir or task file** (`docs/specs/<slug>/`, `.docs/specs/<slug>/`,
   `~/.smithy/plans/<repo>/<slug>/`; `smithy tasks where` lists them; an `NN-*.md`; or "the tasks we
   just planned"): `smithy tasks ready <dir>` gives what can start; blocked ones wait for their
   blockers. Id = `<slug>-NN`. Source = the file.
2. **Board ids** (GitHub issues, Linear, Jira keys): read each with `gh` or the harness's tracker
   tools. Id = the key. Source = the board.
3. **Tasks inline**, one per line: id `task-<slug>`. Source = none (only `batch.json`).
4. **Just an idea** (one goal, no split): ask once, recommendation first, offering only what is
   installed:
   - "Do you have a plan or task file? Give me the path or the board."
   - "Plan it with smelt" (when installed): the user runs `/smelt plan <idea>`; when its task list
     exists, continue at 1.
   - "I split it quickly": read the code, propose 2–6 tasks in the task-file format (vertical
     slices, real blockers only) in one message, write them once approved to the dir
     `smithy task-dir <slug>` gives (same settings and questions as smelt), continue at 1.
   - "Run it as one task": continue at 3 with the idea as the only line.
   Under `/hush`, don't ask: split when the idea clearly has independent parts, else one task.

## Worker mode

Once per batch, unless the user said it or `warden.mode` is set: with smelt installed ask "smelt
(fast / normal / full) or plain?", default `smelt fast`. Without smelt: `plain`, no question.
Store it as `mode` in `batch.json`. A `(full)` item overrides the batch speed.

## Kinds

`ship` (default) ends in a PR. `scout` ("investigate", "compare", "find out why") ends in
`report.md` in the batch dir and no PR; with the scout skill installed (`smithy skills scout`) its
worker follows that SKILL.md and writes the report there.

## Base branch

Per task: the user's words, else inferred (a hotfix starts from and targets the production
branch; anything else the integration branch, e.g. `develop`, else the default branch). State
each item's base in the plan; ask only when it stays ambiguous. A PR into the production branch
is `manual` unless the user's intent says to release it.

## Status back to the source

So smelt and the board stay in sync:
- Local task dir: `smithy tasks set <file> status=doing` at launch, `status=done pr=<url>` when merged,
  `status=dropped` when dropped.
- Committed repo task dir (`docs/specs`): the worker sets `Status: done` and `PR:` in its own
  branch, so it lands with the PR; you don't commit to the base branch.
- Uncommitted repo task dir (`.docs/specs`): update it directly, like a local dir.
- Board: one comment with the PR when it opens; close or move the issue when merged (only what the
  tracker's tools allow; never delete).
