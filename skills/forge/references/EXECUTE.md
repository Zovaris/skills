# Execute a task list here

`/forge build all [dir]` works every task of a task list in this session, one fresh implementer
**subagent** per task, so your own context only holds briefs, diffs and rulings. For tasks that
can run at the same time in separate worktrees and PRs, `/foreman <dir>` is the parallel
alternative.

## Models

Each implementer gets the model `scripts/route.js --file <task file> --speed <speed>` picks
(cheap, mid or strong, from the task's risk, difficulty and size); reviewers use
`route.js --kind review`; the last fix round goes one tier up. You may move a pick one tier with
a reason; a model the user named always wins. A tier whose model is unset prints `-`: propose
`scripts/config.sh suggest-models` and save on a yes (`config.sh accept-models`), or ask for each
tier when there are no suggestions; until then use the session default.

## Loop

`scripts/tasks.js list <dir>` first; work `scripts/tasks.js next <dir>` until it says all done.
For each task:

1. `tasks.js set <file> status=doing`.
2. **Brief.** Prompt = `agents/implementer.md` + `## Inputs`: the task file's path and text, the
   spec path, the test commands from `stack.sh`, the files and interfaces the task lists, and
   the rulings so far that touch it. Never your conversation.
3. **Status.** The implementer ends with one of:
   - `DONE` → step 4.
   - `DONE_WITH_CONCERNS` → read the concerns, decide each (ruling), then step 4.
   - `NEEDS_CONTEXT` → answer from the spec or code (ruling) and send it back; if only the user
     can answer, ask (under `/silent`, decide and rule).
   - `BLOCKED` → `tasks.js set <file> status=todo`, note why, move to the next unblocked task.
4. **Verify** per `references/VERIFY.md`: read the diff, run the task's tests and the suite.
5. **Review** the diff with a fresh `agents/spec-check.md` (task file as the spec) and, at
   `normal`/`full`, `agents/standards.md`. Handle findings per `references/RECEIVING.md`.
6. **Fix loop**: send the reproduced findings back to a fresh implementer with the diff. At most
   3 rounds; round 3 uses the strong model. Still failing → `BLOCKED` with the findings.
7. Commit the task atomically (`scripts/commit.sh`), `tasks.js set <file> status=done`.

After the last task: one whole-branch review (`references/REVIEW.md`), one fix wave, then ship.

## Rulings

Decisions that come up without the user, by impact:
- **low** (local, cheap to undo): decide yourself.
- **medium** (shapes a module or an internal contract): `scripts/consult.sh "<question>"
  "<options, neutral order>" [--context <file>]`, one tool-less call to the user's strong model
  in whatever harness you're in. Follow its pick; `NEED-INFO` → find that out and ask again;
  `ESCALATE` → it's high.
- **high** (scope, customer-visible behaviour, money, data, security, public API, production,
  irreversible): the user decides.

Every decision made without the user is one line in `<dir>/rulings.md`:
`- NN · <question> → <choice> (why)`. Rulings bind later tasks (pass the relevant ones in each
brief) and become the PR's "Decided without you". A ruling that turns out to be the user's call
goes to them before ship.
