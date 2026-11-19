# Test agents

Launch each as a fresh **subagent**: prompt = the agent file's text, a `## You get` block with
exactly what the file lists, and the report contract below. Agents that write tests work in
their own git worktree, cut from your current commit, never from the base branch: make a WIP commit first
(`git commit -m "wip: test agents"`; at ship, `git reset --soft <base>` and make the atomic commits), then
`git worktree add <absolute path outside the repo> HEAD` (`smithy names worktree <branch>-<agent>`
gives one) (or the harness's isolation option when it starts from HEAD) and
pass the path. Their tests are input, not files to ship: move the cases worth keeping into the
repo's existing test files in its own naming, drop the rest and any reference to the agent or
its spec, and never commit an agent's file as is. Then remove those worktrees and branches
(`smithy cleanup`). Launch them together so they run in parallel. Without a subagent tool: write each prompt to a file and run
`smithy agent --bg --cwd <worktree> --log <file> <prompt-file>` per agent, then read the logs.
Read-only agents (spec-check, standards, security, builder) run as any fresh subagent (no
particular type needed), or with `smithy agent --readonly` without a subagent tool.
Give every agent the absolute path of this skill's `scripts/smithy` as `<smithy>`: agents run in the
repo, not in the skill folder.

Every prompt ends with this **report contract**, since agents see only their prompt:

```
## Report
Work silently: no narration, no questions to the user. Your report is your only output, in the
shape your file asks for (its status block included), then one last line
`done: <one-line result>`. Anything you can't settle goes in the report as a question with your
recommendation; never stop to ask.
```

All test agents of a speed run together, in parallel, before review. Which ones run depends on the speed (table in SKILL.md); within it, use this to choose.

| Agent | Run when | Cost | Writes tests |
|---|---|---|---|
| `agents/adversary.md` | any non-trivial logic; run 2 when the logic is risky | medium | yes |
| `agents/regression.md` | every bug fix | low | no (runs the fixer's test) |
| `agents/property.md` | parsers, serializers, math, money, sorting, state machines, invariants such as length bounds or round-trips on pure functions | medium | yes |
| `agents/mutation.md` | before merge on core logic, when `smithy stack` shows a mutation tool | high CPU | proposes |
| `agents/e2e.md` | UI flows or HTTP endpoints changed and the app can run locally | high | yes |
| `agents/hostile.md` | after review, on a runnable CLI, API, worker or job that takes outside input, retries, writes state or calls dependencies | high | no (reports) |
| `agents/spec-check.md` | always in review | low | no |
| `agents/standards.md` | always in review | low | no |

Hostile runs last: after the diff is reviewed, against a build of the reviewed commit. Any fix
it triggers goes through build (failing test first) and review again; its findings close on the
re-run of its repro, not on your word.

Characterization: before a refactor of untested code, snapshot current behaviour first
(vitest/jest `toMatchSnapshot`, Python syrupy/approvaltests), refactor, require zero diffs.
Never update snapshots in the same pass.

## What each agent must not get

Your conversation, plan, reasoning or opinion of the code. Give the spec/criteria, the public
interface (signatures, types, routes), the test commands from `smithy stack`, and the changed files
list only where the file says so. Independence is the point: an agent that knows how you thought
shares your blind spots.

## Handling reports

Every finding comes with a command and its output. For each:
1. Re-run it yourself. Not reproduced → drop it (note it).
2. Spec violation → keep the failing test, fix the code (the test is the red step).
3. Spec ambiguous → decide (or ask the user when it's theirs), update the spec, then 2 or drop.
4. Test is wrong → reject with one line.

Reject outright any change that weakens an assertion, deletes or skips a test, or edits source.

## Deterministic gates (no agent needed)

Prefer scripts and hooks for what they can decide: typecheck, lint, full suite, coverage on
changed lines (`diff-cover` for Python or any lcov; `vitest --coverage --changed`), flaky checks
(`pytest -p randomly --count 3`, `vitest --sequence.shuffle`, `playwright --repeat-each 3`).
