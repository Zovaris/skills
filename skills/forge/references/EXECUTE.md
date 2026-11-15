# Execute a task list here

`/forge build all [dir]` works every task of a task list in this session, one fresh implementer
**subagent** per task, so your own context only holds briefs, diffs and rulings. For tasks that
can run at the same time in separate worktrees and PRs, `/foreman <dir>` is the parallel
alternative.

## Models

Implementers and reviewers use `scripts/config.sh model cheap` by default and
`config.sh model strong` on the last fix round. Exit 3 means unset: ask the user once ("Which
cheap and which strong model should forge's subagents use here?"), save with
`config.sh set-model cheap|strong <name>`, and until then use the harness default.

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

Every decision you make instead of the user is one line in `<dir>/rulings.md`:
`- NN · <question> → <choice> (why)`. Rulings bind later tasks (pass the relevant ones in each
brief) and become the PR's "Decided without you". A ruling that turns out to be the user's call
goes to them before ship.
