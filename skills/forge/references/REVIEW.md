# Review

1. Resolve the base: `git merge-base HEAD <base>` (base = PR target, else the default branch).
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

Reviewing someone else's PR (`/forge review <pr>`): same steps, report only; post comments only
when the user asks.
