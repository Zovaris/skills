---
name: tend
description: Keeps open pull requests mergeable after their author has ended — fixes red CI, rebases or merges the base when behind or conflicting, answers review comments — and stops when each PR is merged, closed or needs the user. Run as /tend <pr-url|number|branch> [...] or /tend batch <foreman batch>; foreman also launches it.
disable-model-invocation: true
argument-hint: "<pr-url|number|branch> [...] | batch <foreman batch> [--card <status.js> <batch> <id>]"
---

# tend

You look after PRs someone else opened (a person, a forge session, a foreman worker) until they
can merge. You fix what blocks them; you don't add scope. Work silently (the `silent` skill's
rules if installed): no talk between tool calls, one line per PR at the end.

Scripts are in `<skill-dir>/scripts/`: `pr-state.sh` (compact PR state), `verify.sh` (pushed
head, checks, mergeable), `commit.sh` (commits in the repo's style).

## Input

- PR urls, numbers or branch names: one loop per PR.
- `batch <name>`: every item of that foreman batch in state `pr_open` or `ready`
  (`<foreman-dir>/scripts/status.js board <name> --json`).
- `--card <status.js> <batch> <id>`: when foreman launched you, mirror your state on that card
  (`node <status.js> set <batch> <id> state=… note=…`).

## Loop, per PR

Check out the PR's branch in its existing worktree if there is one (`git worktree list`), else a
new one under `worktrees/tend-<n>`; never in the user's main checkout. Then repeat:

1. `scripts/pr-state.sh <pr>` → `{state, checks, mergeable, review, unresolved, behind}`.
2. Act on the first thing that applies:
   - **merged / closed** → stop this PR.
   - **checks fail** → `gh run view <run> --log-failed`. Reproduce locally if you can. Same
     test passes on a plain rerun and nothing in the diff touches it → flaky: rerun once
     (`gh run rerun <run> --failed`) and note it. Otherwise fix it with a failing test first
     when it's a real bug.
   - **conflicting or behind base** → follow the repo: rebase if its history is linear (no merge
     commits on the base in `git log --merges -5`), else merge the base. A rebase needs a force
     push: `--force-with-lease` only on branches tend or foreman created (`foreman/…`,
     `tend/…`, or listed in the batch); on anyone else's branch, merge the base instead or stop
     with "needs you". Conflicts you can't resolve from both sides' intent → stop with
     "needs you".
   - **unresolved review threads** (human or bot) → `references/RECEIVING.md`. At most 3 rounds
     per PR; the count lives in the card's `review_rounds` or `.tend/<pr>.rounds`.
   - **checks pending** → wait with one blocking command: `gh pr checks <pr> --watch`, or an
     `until …; do sleep 30; done` loop with a 600000 ms Bash timeout. Never sleep-then-check
     turns.
   - **green, mergeable, approved or no review required** → stop: `green`. Merge only if the
     user or foreman said this PR is `merge auto`, and never into the production branch.
3. Commit fixes with `scripts/commit.sh` (style once, one concern per commit); push without force
   unless the rebase rule above allows it.

## Stop and hand back

Stop a PR, set the card if any, and move to the next when:
- **merged / closed / green** — done.
- **needs you**: a decision the user owns (scope, API, data, security), a conflict you can't
  resolve safely, red twice after real fixes, 3 review rounds used, or a force push you aren't
  allowed to do.

## End

One line per PR, nothing else:

```
merged <url>
green <url>
needs you <url>: <why, one line>
```
