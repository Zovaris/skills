---
name: smelt
description: Runs an engineering workflow (brainstorm, spec, task list, TDD build, test agents, review, verify, PR) at a chosen speed (fast, normal or full), from any phase. Invoked by the user as /smelt.
disable-model-invocation: true
argument-hint: "[brainstorm|plan|spec|build [next|all]|test|review|ship|debug|adr|retro|init | from <phase>] [fast|full] <task or path>"
---

# smelt

One workflow in phases with exit gates. Start wherever the user already is, run only what the
speed calls for, and read a reference only when its phase starts. Paths are relative to
`<skill-dir>` (this file's folder). Works in any agent harness: where this file says
**subagent**, use your harness's subagent tool with a fresh context; without one, write the
prompt to a file and run `scripts/agent.sh [--readonly] <prompt-file>` (any agent CLI). An
**agent** is such a subagent given one of the prompts in `agents/` (implementer, test agents,
reviewers); it sees only what that prompt lists.
Subagent models: `scripts/route.js` picks cheap, mid or strong per job from the task itself
(read-only agents and reviews cheap, risky or hard work strong); unset tiers → propose
`scripts/config.sh suggest-models` (or ask for each tier when there are none) and save the
user's yes.

## Pick the entry point

| Command | Runs |
|---|---|
| `/smelt <task>` | infer: no agreed plan → `plan`; plan/spec/task exists → `build`; a bug → `debug` |
| `/smelt brainstorm <idea>` | `references/BRAINSTORM.md` only: the why, approaches, a draft design |
| `/smelt plan <idea>` | brainstorm → grill → spec → builder check → task list → ask how to run it |
| `/smelt build next [dir]` | `scripts/tasks.js next`, mark it `doing`, build it to `ship`, mark it `done` |
| `/smelt build all [dir]` | `references/EXECUTE.md`: every task here, one implementer subagent each |
| `/smelt <phase> <task>` | that phase only: `spec`, `build`, `test`, `review`, `ship`, `retro` |
| `/smelt from <phase> <task>` | that phase to the end, e.g. `from test` on code you already wrote |
| `/smelt debug <bug>` | `references/DEBUG.md` → build (fix) → test (`agents/regression.md`) → review → ship |
| `/smelt adr <title>` · `/smelt init` | with the ledger skill installed (`scripts/find-skill.sh ledger`), follow its `adr` / `init` mode; else `references/DOCS.md`. **Done:** the files are written and listed |

Already have a plan in your head or in the chat? That *is* the spec: start at `build` and treat
the agreed points as the acceptance criteria; don't re-plan.

## Pick the speed

Say the speed and the phases you'll run in one line before starting.

| | fast | normal (default) | full |
|---|---|---|---|
| For | small or clear changes, warden workers | most features and fixes | risky logic, money, data, auth, public APIs |
| Plan / spec | skipped; criteria from the task | spec if none exists | brainstorm + grill + spec + builder check + tasks |
| Build | TDD on the acceptance criteria only | TDD on every behaviour | TDD on every behaviour |
| Test agents | regression (bugs) | + adversary; property or e2e when the change fits | + 2 adversaries, property, mutation, e2e when applicable |
| Review | self-check against `agents/spec-check.md`; security only if the change is risky | spec-check + standards (+ security if risky) | spec-check + standards + security |
| Verify gate | always | always | always |
| Docs | ADR only if forced | glossary/ADR when they apply | glossary/ADR when they apply + retro |

`fast` should finish in one sitting: no agent that needs the app running, no mutation run,
full suite once at the end. A trivial change (copy, style, one-liner) is always `fast`.
Risky means the change touches auth, money, personal data, input parsing, file or shell access,
or secrets. Under `/hush`, never ask: pick the speed yourself and say which at the end.

## Phases

**0 · Context** (always). Read, if they exist: the repo's agent instructions (AGENTS.md /
CLAUDE.md), `docs/GLOSSARY.md`, titles of `docs/adr/*` (open the ones that touch the task),
`docs/agents/STANDARDS.md`, and the spec/task given. With the ledger skill installed
(`scripts/find-skill.sh ledger`), follow its context rules; else `references/DOCS.md`.
Run `scripts/stack.sh` once and use its commands instead of guessing. Note whether you're in a
worktree (`git rev-parse --git-dir` differs from `--git-common-dir`) and run the suite once as a
baseline: failures that exist before you start aren't yours, but say so.
**Done:** you can name the seams the change touches and the baseline result.

**plan · Brainstorm and grill** — `references/BRAINSTORM.md`, then `references/GRILLING.md`.
The why first, then 2–3 approaches the user picks from, a short design, then the remaining
decisions down the design tree. Facts you look up (the `scout` skill when installed);
decisions are the user's. ADR candidates: with the ledger skill installed, its `adr` mode once
the user confirms; else `references/DOCS.md`.
**Done:** the user approved the design and confirmed the decisions.

**spec · Spec and tasks** — `references/SPEC.md`, then `references/TASKS.md`. Spec with agreed
test seams; at `full` or for a long spec, a fresh `agents/builder.md` subagent sorts what's
still open into answered / minor (decide) / theirs (ask). Then tracer-bullet tasks with Files
and Interfaces, self-reviewed, where the user picks; then ask how to run them: here one at a
time (`build next`), here all at once (`build all`), in parallel with warden (if installed),
or later. **Done:** spec + tasks written, each fits one fresh context; the user chose.

**build · TDD** — `references/TDD.md`. From a task file: `scripts/tasks.js set <file> status=doing`
first, `status=done pr=<url>` after ship. One test at a time at the agreed seams; each fails
for the right reason before any code; never edit a test to go green (if it contradicts the
spec, stop and say so). Single test files while working, typecheck often, full suite at the
end. **Done:** `references/VERIFY.md` gate for "suite, typecheck and lint green" and "every
criterion has a test".

**test · Attack** — `references/TESTING.md`. Launch the speed's agents as parallel
**subagents**, each with only what its file in `agents/` lists, never your plan or reasoning.
Agents that write tests work in their own git worktree. You fix the code; they never do.
**Done:** every reproduced finding fixed (failing test first) or rejected with one line; VERIFY
gate on the suite.

**review** — `references/REVIEW.md` (findings: `references/RECEIVING.md`). Fresh **subagents**: `agents/standards.md`,
`agents/spec-check.md`, and `agents/security.md` when the speed or the change calls for it;
never merge or rerank their reports. Findings and human PR comments: `references/RECEIVING.md`.
**Done:** no open blocking finding; every high security finding shown to the user.

**ship.** Docs first: with the ledger skill installed, its `sync` mode on the diff and its
`comments` check on the changed files (API doc comments only, the why goes to docs); else update
the docs the change touched (`references/DOCS.md`). Then:
- **Branch:** still on the base? `git switch -c "$(scripts/names.sh branch <key|-> "<title>")"`
  (`<key>`: the ticket, issue or task `NN`). Never invent another naming scheme.
- **Integrate:** full suite on the tree you're about to ship (after rebasing or merging the
  base), VERIFY gate. Red → back to build.
- **Atomic commits** with `scripts/commit.sh`: `commit.sh style` once, then one commit per
  concern (`commit.sh "<msg>" <paths>`), each building and passing on its own. Never
  `git add -A`, never `--no-verify`.
- **Close, one of three.** (1) **PR**, the default, with `scripts/pr.sh`: if `pr.sh template`
  finds one, fill every heading (N/A when one doesn't apply); otherwise what and why, tests
  added, commands run with results, agents run and what they found, "Decided without you" (from
  `rulings.md` if any), ADRs added. Title in the commit style:
  `pr.sh create --base <b> --title "<t>" --body-file <f>`. (2) **Merge locally** into the base
  only when the user asks. (3) **Keep** the branch for later. Discard work only when the user
  explicitly says to.
- **Clean up** once merged or discarded: `scripts/cleanup.sh <repo> <branch> [<worktree>]`,
  only for worktrees and branches smelt created. It refuses to drop unpushed work; never force it.
**Done:** VERIFY gate for "PR ready" (or committed when there's no remote); no stray worktrees
or local branches from this task.

**retro** — `references/DOCS.md`. Mechanical mistakes → an automated check; judgement calls →
`docs/agents/STANDARDS.md`; facts about the user → the harness's memory; project facts → repo
docs. Propose, write what the user accepts. **Done:** each accepted lesson is written and
listed; the rest are named as dropped.

## Always

- Ask only for decisions that are the user's. When you'd otherwise stop to ask (under
  `/hush`, in `build all`, or the user is away): low impact → decide; medium → one
  `scripts/consult.sh` call to the user's strong model; high → the user. Record each in the PR's
  "Decided without you".
- No claim without fresh evidence (`references/VERIFY.md`): every "passes" names the command
  and its result; every "an agent did it" comes with its diff.
- Never `--no-verify`, never skip or delete a failing test to go green.
- Keep a short task list of the phases you're running (your harness's to-do tool if it has
  one) and tick it as you go; it is the user's progress view.

## Red flags

Phase-specific ones live in TDD, DEBUG and VERIFY; these cover the whole workflow.

| Thought | Reality |
|---|---|
| "Too small for the workflow" | Then it's `fast`, not skipped: a test and the verify gate still. |
| "I know what they want, skip the questions" | Your belief is thinner than it feels. Ask the one question that matters. |
| "Let me clean up these old branches too" | Only what smelt created. Never force. |
