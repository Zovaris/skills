# Review

1. Resolve the base: `git fetch origin <base>`, then `git merge-base HEAD origin/<base>` (base =
   PR target, else the default branch). Never the local `<base>`: it goes stale in worktrees.
   Reviewers diff the working tree against it, `git diff <merge-base>`, so committed and
   uncommitted work are both reviewed (`git add -N <new files>` first so new files show).
   Empty diff → say so and stop.
2. Find the spec: the task/spec path you were given, commit messages, the PR body, or
   `docs/specs/`. None → spec-check reviews against the PR description and says so.
3. Launch fresh **subagents** in parallel (read-only), each prompt ending in the report contract
   (`references/TESTING.md`), at the speed set in SKILL.md. At `normal`, spec-check and standards
   run as one subagent given both files, returning both reports one after the other:
   - `agents/spec-check.md` always, with the diff command and the spec path.
   - `agents/standards.md` at `normal` and `full`, with the diff command and the paths of the
     repo's rules (AGENTS.md / CLAUDE.md, CONTRIBUTING.md, `docs/agents/STANDARDS.md`, lint config); with none of
     those, the ground rules in use-smithy section 3 and the language's formatter and linter.
     Lines that `smithy decide rules --base <merge-base>` prints (nothing when it is off) go
     with them as leads to check, not findings. When on, it sends the diff and rule lines to the
     endpoint the user configured.
   - `agents/security.md` at `full` speed, and at any speed when the diff touches auth, money,
     personal data, input parsing, file or shell access, or secrets. Its high findings are the
     user's to see before merge.
4. Show the reports separately, as returned (a combined reviewer's two reports stay two). Don't merge, dedupe or rerank them: they answer
   different questions. Blocking: a spec-check `missing`, `partial` or `wrong`; a failing holdout, adversary or
   regression test; a violation of a rule in `docs/agents/STANDARDS.md`. A high security finding
   is shown to the user. Every other finding is advisory.
5. Handle each finding with the receiving-review rules: verify, then fix (bug findings: failing
   test first) or decline. Give every finding a disposition in the PR body (or the final message):
   `fixed`, `declined: <why>`, `false positive` or `not reproduced`.
6. **The reviewer closes, not you.** At `full` speed, and at any speed for any blocking finding
   you fixed or a high security finding you fixed, send one fresh subagent per round the fixes'
   diff, every fixed finding, the agent files they came from and `smithy receipt list` output,
   asked only "is each finding resolved, and did the fixes add a new problem?".
   One bounded second look per round, covering every fixed finding; a finding it keeps open goes back to step 5, and a
   second "still open" goes to the user.
7. **Another look only when it pays.** After fixing what a second look kept open, decide with
   judgment, not by habit: a fix that changes behaviour, touches a risky area or is more than a
   few lines gets one more look from the same agent file; a rename, a comment, a commit message
   or a test-only addition doesn't. Say which you chose in one line in the PR body; when no
   second look ran, there is nothing to log.

Reviewing someone else's PR (`/smelt review <pr>`): same steps, report only; post comments only
when the user asks.
