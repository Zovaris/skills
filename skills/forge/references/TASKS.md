# Tasks

The task list is the hand-off between planning and building, and between forge and foreman.
Whoever wrote it, either skill (or you, by hand) can pick it up. `scripts/tasks.js` reads and
updates it; never hand-edit status lines when the script can.

## Where it lives

Use the user's default, `scripts/config.sh get tasks.location` (`repo`, `local` or `board`), and
`config.sh get tasks.commit` (default `true`). Unset → ask once at the end of the spec, with
your recommendation first, and offer to save the answer with `config.sh set`:

| Choice | Where | When |
|---|---|---|
| Board | the user's tracker (GitHub Issues via `gh`, or Linear/Jira through the harness's tools) | the user already works from a board |
| Repo, committed (`tasks.commit` true, the default) | `docs/specs/<slug>/` | the plan is versioned and reviewed with the code |
| Repo, not committed (`tasks.commit` false) | `.docs/specs/<slug>/`, with `.docs/` added to `.git/info/exclude` (local, so the ignore isn't committed either) | next to the code, but specs stay out of git |
| Local | `~/.agents/plans/<repo>/<slug>/` (`$FORGE_PLANS`) | private notes outside the repo |

Other places: list them in `$FORGE_TASKS_DIRS` (colon-separated) so `tasks.js` finds them.

Board tasks still get the same fields (status, blocked by, PR) in the issue body or labels; the
spec stays in the repo or local dir and the issues link to it.

## Splitting

- **Tracer bullets:** each task is a thin vertical slice through every layer that is demoable on
  its own, not a horizontal layer.
- **Prefactor first:** "make the change easy, then make the easy change". Wide renames or
  migrations use expand → migrate → contract tasks.
- Each fits one fresh context window; split anything bigger than ~1 day of human work.
- `Blocked by` only for real dependencies (one task needs another's code or schema). Tasks that
  merely touch nearby files are not blocked; tasks that would edit the same lines are.
- **Self-review** before showing it:
  1. Coverage: every acceptance criterion of the spec lands in exactly one task.
  2. Interfaces line up: each `Consumes` is `Produces`d by a blocker or already exists.
  3. Collisions: tasks without a `Blocked by` between them don't modify the same files.
  4. Proportion: no task is a horizontal layer, none is bigger than a day, none is trivial
     enough to merge into its neighbour.
- Show the list (number, title, one line, blocked by) and wait for approval before writing.

## Task file — `NN-<slug>.md`

```markdown
# NN · <title>
Status: todo
Blocked by: <NN, NN | none>
PR: -
Spec: ./spec.md

## What
<one paragraph>

## Acceptance criteria
- [ ] <from the spec, narrowed to this slice>

## Files
- create: <path> · modify: <path> · test: <path>

## Interfaces
- Consumes: <functions, types, endpoints, tables it relies on, with signatures>
- Produces: <what it adds or changes for later tasks, with signatures>

## Notes
<seams, risks>
```

Files and Interfaces are what lets a fresh implementer (or a foreman worker) start without
reading the whole plan, and what tells you two tasks would collide.

Status moves `todo → doing → done` (or `dropped` with a line saying why). Whoever starts a task
sets `doing`; whoever lands it sets `done` and `PR`. In a repo task dir the `done` + `PR` change is
committed in the task's own branch, so it lands with the PR; nothing is committed to the base
branch just to move a status. Uncommitted dirs (`.docs/specs`), local dirs and boards are
updated directly.

## Commands

```
scripts/tasks.js list  [dir]          # the board: status, blockers, PR per task
scripts/tasks.js next  [dir]          # first todo whose blockers are done
scripts/tasks.js ready [dir]          # every todo that can start now (what foreman launches)
scripts/tasks.js set <file> status=doing|done pr=<url>
scripts/tasks.js where                # task dirs for this repo (repo and local)
```

## After the list is written

Ask how to run it, recommendation first, only offering what is installed:
- **Here, one at a time:** `/forge build next` (repeat until `tasks.js next` says all done).
- **In parallel:** `/foreman <task dir>` when the foreman skill is installed (it is listed among
  your skills, or `<skill-dir>/../foreman/SKILL.md` exists). Mixing is fine: build some here,
  hand the rest over; both read and write the same status lines.
- **Later:** stop here; the list waits.
