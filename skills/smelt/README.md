# smelt

One engineering task, step by step: brainstorm → spec → task list → test-first build →
independent test agents → review → PR → retro. Start at any phase, at the speed the task needs.

Started by you (by name, the way your harness starts skills) or by an agent through use-smithy.

## Commands

| Command | Does |
|---|---|
| `/smelt <task>` | Picks the entry: no plan → `plan`, a plan or task → `build`, a bug → `debug` |
| `/smelt plan <idea>` | Brainstorm, grill the open decisions, write the spec and the task list |
| `/smelt build next` · `build all` | Build the next ready task, or every task with one implementer each |
| `/smelt <phase> <task>` | One phase: `brainstorm`, `spec`, `build`, `test`, `review`, `ship`, `retro` |
| `/smelt from test <task>` | From that phase to the end, e.g. on code you already wrote |
| `/smelt debug <bug>` | Root cause, failing test, fix, regression test, PR |

## Speeds

| | fast | normal (default) | full |
|---|---|---|---|
| For | small or clear changes | most features and fixes | auth, money, data, public APIs |
| Plan | criteria from the task | a spec if none exists | brainstorm, grill, spec, tasks |
| Test agents | regression for bugs | + adversary, property or E2E when it fits | + mutation, two adversaries, hostile run after review |
| Review | spec check | spec + standards | spec + standards + security |

Every speed builds test-first and passes the verify gate: no "done" without fresh evidence.

## What you get

- A spec and a task list (`NN-<slug>.md`) in `docs/specs/`, `.docs/specs/` or `~/.smithy/plans/`.
- Atomic commits in your repo's style and a PR filled from your template.
- A branch named `<type>/<key>-<slug>`, cleaned up after merge.

Hand the task list to **warden** to build it in parallel.
