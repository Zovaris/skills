# Review

1. Resolve the base: `git fetch origin <base>`, then `git merge-base HEAD origin/<base>` (base =
   PR target, else the default branch). Never the local `<base>`: it goes stale in worktrees.
   Empty diff → say so and stop.
2. Find the spec: the task/spec path you were given, commit messages, the PR body, or
   `docs/specs/`. None → spec-check reviews against the PR description and says so.
3. Launch fresh **subagents** in parallel (read-only):
   - `agents/standards.md` with the diff command and the paths of the repo's rules
     (AGENTS.md / CLAUDE.md, `docs/agents/STANDARDS.md`, lint config).
   - `agents/spec-check.md` with the diff command and the spec path.
   - `agents/security.md` at `full` speed, and at any speed when the diff touches auth, money,
     personal data, input parsing, file or shell access, or secrets. Its high findings are the
     user's to see before merge.
4. Show the reports separately, as returned. Don't merge, dedupe or rerank them: they answer
   different questions.
5. Handle each finding with the receiving-review rules: verify, then fix (bug findings: failing
   test first) or decline with one line of reason in the PR body or the final message.
6. **The reviewer closes, not you.** At `full` speed, and at any speed for a blocking or high
   security finding you fixed, send the fix's diff and the finding to a fresh subagent with the
   same agent file, asked only "is this finding resolved, and did the fix add a new problem?".
   One bounded second look per finding; a finding it keeps open goes back to step 5, and a
   second "still open" goes to the user.
7. **Another look only when it pays.** After fixing what a second look kept open, decide with
   judgment, not by habit: a fix that changes behaviour, touches a risky area or is more than a
   few lines gets one more look from the same agent file; a rename, a comment, a commit message
   or a test-only addition doesn't. Say which you chose in one line in the PR body.

Reviewing someone else's PR (`/smelt review <pr>`): same steps, report only; post comments only
when the user asks.
