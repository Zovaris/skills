# Review

1. Resolve the base: `git fetch origin <base>`, then `git merge-base HEAD origin/<base>` (base =
   PR target, else the default branch). Never the local `<base>`: it goes stale in worktrees.
   Reviewers diff the working tree against it, `git diff <merge-base>`, so committed and
   uncommitted work are both reviewed (`git add -N <new files>` first so new files show).
   Empty diff → say so and stop.
2. Find the spec: the task/spec path you were given, commit messages, the PR body, or
   `docs/specs/`. None → spec-check reviews against the PR description and says so.
3. Launch fresh **subagents** in parallel (read-only), each prompt ending in the report contract
   (`references/TESTING.md`), at the speed set in SKILL.md:
   - `agents/spec-check.md` always, with the diff command and the spec path.
   - `agents/standards.md` at `normal` and `full`, with the diff command and the paths of the
     repo's rules (AGENTS.md / CLAUDE.md, CONTRIBUTING.md, `docs/agents/STANDARDS.md`, lint config); with none of
     those, the ground rules in use-smithy section 3 and the language's formatter and linter.
   - `agents/security.md` at `full` speed, and at any speed when the diff touches auth, money,
     personal data, input parsing, file or shell access, or secrets. Its high findings are the
     user's to see before merge.
4. Show the reports separately, as returned. Don't merge, dedupe or rerank them: they answer
   different questions. Blocking means a spec gap, a correctness bug, or a violation of a rule in
   `docs/agents/STANDARDS.md`; every other standards finding is advisory.
5. Handle each finding with the receiving-review rules: verify, then fix (bug findings: failing
   test first) or decline. Give every finding a disposition in the PR body (or the final message):
   `fixed`, `declined: <why>` or `false positive`, so the reviewers' precision can be read later.
6. **The reviewer closes, not you.** At `full` speed, and at any speed for any blocking finding
   you fixed or a high security finding you fixed, send the fix's diff and the finding to a fresh subagent with the
   same agent file, asked only "is this finding resolved, and did the fix add a new problem?".
   One bounded second look per finding; a finding it keeps open goes back to step 5, and a
   second "still open" goes to the user.
7. **Another look only when it pays.** After fixing what a second look kept open, decide with
   judgment, not by habit: a fix that changes behaviour, touches a risky area or is more than a
   few lines gets one more look from the same agent file; a rename, a comment, a commit message
   or a test-only addition doesn't. Say which you chose in one line in the PR body; when no
   second look ran, there is nothing to log.

Reviewing someone else's PR (`/smelt review <pr>`): same steps, report only; post comments only
when the user asks.
