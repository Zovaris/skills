# Ship

Docs first: `smithy comments --diff <base>` on the changed files (API doc comments
only, the why goes to docs); with the ledger skill installed, also its `sync` mode on the diff,
else update the docs the change touched (`references/DOCS.md`). Then:
- **Branch:** still on the base? `git switch -c "$(smithy names branch <key|-> "<title>")"`
  (`<key>`: the ticket, issue or task `NN`). Already on a branch the harness or the user made
  for this work? Keep it. Never invent another naming scheme.
- **Integrate:** full suite on the tree you're about to ship (after rebasing or merging the
  base), VERIFY gate. Red → back to build.
- **Atomic commits** with `smithy commit` (review read the working tree, so this comes after it;
  a WIP commit made for test-agent worktrees is undone first with `git reset --soft <base>`): `smithy commit style` once, then one commit per
  concern (`smithy commit "<msg>" <paths>`), each building and passing on its own. Never
  `git add -A`, never `--no-verify`.
- **Scan** with `smithy scan --base <base>` (a branch name resolves to `origin/<base>`) before
  anything leaves the machine: a finding is removed (and the secret rotated if it was ever pushed)
  or marked `smithy:allow` with the user's yes. Never push past a finding.
- **Close, one of three.** (1) **PR**, the default, with `smithy pr create`: if `smithy pr
  template` finds one, fill every heading (N/A when one doesn't apply); otherwise what and why,
  tests added, commands run with results (paste `smithy receipt list --md`), agents run and what
  they found, agents not run and why, "Decided without you" (from `rulings.md` if any), ADRs
  added. Title in the commit style: `smithy pr create --base <b> --title "<t>" --body-file <f>`;
  write the PR body file inside the worktree's `.smelt/` or the system temp dir, never next to
  the worktree. From a task file: `smithy tasks set <file> status=done pr=<url>`. Then hand the
  PR to **tend** when it is installed (`smithy skills tend` prints its path): one silent
  **subagent** on the tier `smithy route --agent tend` gives, prompt "Read <tend-skill> and follow it for <pr-url>; never merge;
  stay until merged or closed; on merge, clean up <branch> [<worktree>]" (name the worktree only
  when smelt created it; a harness-made one belongs to the harness) plus the report
  contract (`references/TESTING.md`); it keeps CI green, rebases and answers review until the PR
  is mergeable or needs the user, then waits for the merge so it can clean up. Without tend, wait
  with `smithy wait pr:<pr-url>`, in the background where the harness wakes on exit, else in the
  foreground; never sleep loops; on merge, clean up yourself.
  (2) **Merge** the PR or locally into the base only when the user asks or the session that
  launched you said `merge auto` (a warden worker); into the production
  branch only on their explicit yes for this change. (3) **Keep** the branch for later. Discard
  work only when the user explicitly says to.
- **No remote** (`git remote` prints nothing): commit, branch, receipts and scan as above, then
  skip the PR, tend and the wait, and say so in the final message.
- **Clean up** once merged or discarded: `smithy cleanup <repo> <branch> [<worktree>]`,
  only for worktrees and branches smelt created. It refuses to drop unpushed work; never force it.
  The merge usually comes later, from the user: give tend the branch, and the worktree only
  when smelt created it ("on merge, clean up <branch> [<worktree>]"); `smithy cleanup` never
  removes a worktree it isn't given; end the test and review agents as soon as their
  reports are in, and if this session was started for the task, say in the final message that it
  can be archived once the PR merges.
- **Lesson.** A finding, failed fix or wrong assumption that surprised you and isn't already in
  the code, a test or the repo's docs → one line through the retro rules (`references/DOCS.md`)
  proposed to the user. Nothing new → say "no lesson".
