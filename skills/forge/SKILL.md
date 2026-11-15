---
name: forge
description: Personal engineering workflow — brainstorm and grill the idea, spec and a shared task list, build with TDD, attack it with independent test agents (adversarial, regression, property, mutation, E2E), two-axis review, ship a PR, keep ADRs, glossary and standards. Start at any phase, pick a speed (fast, normal, full), work the task list one at a time or hand it to foreman. Run as /forge [phase|from <phase>] [fast|full] <task>.
disable-model-invocation: true
argument-hint: "[brainstorm|plan|spec|build [next]|test|review|ship|debug|adr|retro|init | from <phase>] [fast|full] <task or path>"
---

# forge

One workflow in phases with exit gates. Start wherever the user already is, run only what the
speed calls for, and read a reference only when its phase starts. Paths are relative to
`<skill-dir>` (this file's folder). Works in any agent harness: where this file says
**subagent**, use your harness's subagent tool with a fresh context; without one, write the
prompt to a file and run `scripts/agent.sh [--readonly] <prompt-file>` (any agent CLI).

## Pick the entry point

| Command | Runs |
|---|---|
| `/forge <task>` | infer: no agreed plan → `plan`; plan/spec/task exists → `build`; a bug → `debug` |
| `/forge brainstorm <idea>` | `references/BRAINSTORM.md` only: the why, approaches, a draft design |
| `/forge plan <idea>` | brainstorm → grill → spec → task list → ask how to run it |
| `/forge build next [dir]` | `scripts/tasks.js next`, mark it `doing`, build it to `ship`, mark it `done` |
| `/forge <phase> <task>` | that phase only: `spec`, `build`, `test`, `review`, `ship`, `retro` |
| `/forge from <phase> <task>` | that phase to the end, e.g. `from test` on code you already wrote |
| `/forge debug <bug>` | `references/DEBUG.md` → build (fix) → test → review → ship |
| `/forge adr <title>` · `/forge init` | `references/DOCS.md` |

Already have a plan in your head or in the chat? That *is* the spec: start at `build` and treat
the agreed points as the acceptance criteria; don't re-plan.

## Pick the speed

Say the speed and the phases you'll run in one line before starting.

| | fast | normal (default) | full |
|---|---|---|---|
| For | small or clear changes, foreman workers | most features and fixes | risky logic, money, data, auth, public APIs |
| Plan / spec | skipped; criteria from the task | spec if none exists | brainstorm + grill + spec + tasks |
| Build | TDD on the acceptance criteria only | TDD on every behaviour | TDD on every behaviour |
| Test agents | regression (bugs) | + adversary; property or e2e when the change fits | + 2 adversaries, property, mutation, e2e when applicable |
| Review | self-check against `agents/spec-check.md` | spec-check + standards agents | spec-check + standards agents |
| Docs | ADR only if forced | glossary/ADR when they apply | glossary/ADR when they apply + retro |

`fast` should finish in one sitting: no agent that needs the app running, no mutation run,
full suite once at the end. A trivial change (copy, style, one-liner) is always `fast`.
Under `/silent`, never ask: pick the speed yourself and say which in the final message.

## Phases

**0 · Context** (always). Read, if they exist: `docs/GLOSSARY.md`, titles of `docs/adr/*` (open
the ones that touch the task), `docs/agents/STANDARDS.md`, the repo's agent instructions
(AGENTS.md / CLAUDE.md), and the spec/task given. Run `scripts/stack.sh` once and use its
commands instead of guessing. **Done:** you can name the seams the change touches.

**plan · Brainstorm and grill** — `references/BRAINSTORM.md`, then `references/GRILLING.md`.
The why first, then 2–3 approaches the user picks from, a short design, then the remaining
decisions down the design tree. Facts you look up; decisions are the user's.
**Done:** the user approved the design and confirmed the decisions.

**spec · Spec and tasks** — `references/SPEC.md`, then `references/TASKS.md`. Spec with agreed
test seams, tracer-bullet tasks in the place the user picks (board, repo or local), then ask how
to run them: here with `build next`, in parallel with foreman (if installed), or later.
**Done:** spec + tasks written, each fits one fresh context; the user chose how to run them.

**build · TDD** — `references/TDD.md`. Working from a task file: `tasks.js set <file>
status=doing` first, `status=done pr=<url>` after ship. One test at a time at the agreed seams; each fails for
the right reason before any code; never edit a test to go green (if it contradicts the spec,
stop and say so). Single test files while working, typecheck often, full suite at the end.
**Done:** suite, typecheck and lint pass; every criterion has a test.

**test · Attack** — `references/TESTING.md`. Launch the speed's agents as parallel
**subagents**, each with only what its file in `agents/` lists, never your plan or reasoning.
Agents that write tests work in their own git worktree. You fix the code; they never do.
**Done:** every reproduced finding fixed (failing test first) or rejected with one line.

**review** — `references/REVIEW.md`. Two fresh **subagents**, `agents/standards.md` and
`agents/spec-check.md`; never merge or rerank their reports. **Done:** no open blocking finding.

**ship.** Update docs the change touched, then:
- **Atomic commits** with `scripts/commit.sh`: read `commit.sh style` once, then one commit per
  concern (`commit.sh "<msg>" <paths>`), each one building and passing on its own. Never
  `git add -A`, never `--no-verify`.
- **PR** with `scripts/pr.sh`: if `pr.sh template` finds one, fill every heading of it (N/A when
  one doesn't apply); otherwise: what and why, tests added, commands actually run with results,
  agents run and what they found, "Decided without you" if any, ADRs added. Title in the commit
  style. `pr.sh create --base <b> --title "<t>" --body-file <f>`.
- **Clean up** once the PR is merged or the work is abandoned: `scripts/cleanup.sh <repo>
  <branch> [<worktree>]` removes the worktree and the local branch (it refuses to drop unpushed
  work). Remote branches are the host's business.
**Done:** PR open with green CI (or committed when there is no remote); no stray worktrees or
local branches from this task.

**retro** — `references/DOCS.md`. Mechanical mistakes → an automated check; judgement calls →
`docs/agents/STANDARDS.md`; facts about the user → the harness's memory; project facts → repo
docs. Propose, write what the user accepts.

## Always

- Ask only for decisions that are the user's; under `/silent` decide and record them.
- Evidence over claims: every "passes" names the command and its result.
- Never `--no-verify`, never skip or delete a failing test to go green, never update snapshots
  in the same pass as a refactor.
- Keep a short task list of the phases you're running (your harness's to-do tool if it has one)
  and tick it as you go; it is the user's progress view.
