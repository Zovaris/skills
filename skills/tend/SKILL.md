---
name: tend
description: Keeps open pull requests mergeable after their author has ended — fixes red CI, rebases or merges the base when behind or conflicting, answers review comments — and stops when each PR is merged, closed or needs the user. Can keep watching for new PRs, and optionally for new labeled issues to queue for foreman. Run as /tend <pr…> | batch <foreman batch> | watch [prs|issues|all]; foreman also launches it.
disable-model-invocation: true
argument-hint: "<pr-url|number|branch> [...] | batch <foreman batch> | watch [prs|issues|all] [--label <l>] [--model <m>] [--fix-model <m>] [--card <status.js> <batch> <id>]"
---

# tend

You look after PRs someone else opened (a person, a forge session, a foreman worker) until they
can merge. You fix what blocks them; you don't add scope. Work silently (the `silent` skill's
rules if installed): no talk between tool calls, one line per PR at the end.

Scripts are in `<skill-dir>/scripts/`: `pr-state.sh` (compact PR state), `verify.sh` (pushed
head, checks, mergeable), `commit.sh` (commits in the repo's style), `watch.sh` (zero-token
wait for new PRs or issues), `config.sh` (the user's models and tend settings).

## Input

- PR urls, numbers or branch names: one loop per PR, then stop.
- `batch <name>`: the items of that foreman batch, each as it reaches `pr_open` or `ready`
  (`<foreman-dir>/scripts/status.js board <name> --json`). Foreman starts you with the workers,
  so between PRs wait with `<foreman-dir>/scripts/watch.sh <name>`; stop when every item is
  final (merged, dropped, reported).
- `watch [scope]`: keep going. Tend the PRs that match, then wait with `scripts/watch.sh` and
  adopt what appears, until the user stops it or `--max-hours` (default 8) passes. Scope:
  - `prs` (default): open PRs by the user, by foreman (`foreman/…` branches) or with `--label`.
  - `issues`: new issues with `--label` (default `agent`); see "Issues" below. Never builds them.
  - `all`: both.
  The default scope is `config.sh get tend.watch` when set, else `prs`.
- `--card <status.js> <batch> <id>`: when foreman launched you, mirror your state on that card.

## Models

- Routine work (reading state, reruns, rebases, merging the base, replying to comments) runs on
  `--model`, else `config.sh model cheap`. Exit 3 means unset: ask the user once which cheap
  model to use here and save it with `config.sh set-model cheap <name>` (under `/silent` or when
  foreman launched you, use the session default instead of asking).
- Code fixes (a real CI failure, a review comment that asks for a change) go to a fresh
  subagent on `--fix-model`, else `config.sh model strong`, else the session default, with only
  the failing output, the PR diff and the comment. You review its diff before committing.

## Loop, per PR

Check out the PR's branch in its existing worktree if there is one (`git worktree list`), else a
new one under `worktrees/tend-<n>`; never in the user's main checkout. Then repeat:

1. `scripts/pr-state.sh <pr>` → `{state, checks, mergeable, review, unresolved, behind}`.
2. Act on the first thing that applies:
   - **merged / closed** → stop this PR; remove the `tend-<n>` worktree you created.
   - **checks fail** → `gh run view <run> --log-failed`. Same test passes on a plain rerun and
     nothing in the diff touches it → flaky: rerun once (`gh run rerun <run> --failed`) and note
     it. Otherwise it is a real failure: hand it to the fix model, failing test first when it is
     a bug, and push the fix. Red again after a second real fix → "needs you".
   - **conflicting or behind base** → follow the repo: rebase if its history is linear (no merge
     commits on the base in `git log --merges -5`), else merge the base. A rebase needs a force
     push: `--force-with-lease` only on branches tend or foreman created (`foreman/…`,
     `tend/…`, or listed in the batch); on anyone else's branch, merge the base instead or stop
     with "needs you". Conflicts you can't resolve from both sides' intent → "needs you".
   - **unresolved review threads** (human or bot) → `references/RECEIVING.md`. At most 3 rounds
     per PR; the count lives in the card's `review_rounds` or `.tend/<pr>.rounds`.
   - **checks pending** → wait with one blocking command: `gh pr checks <pr> --watch`, or an
     `until …; do sleep 30; done` loop with a 600000 ms Bash timeout. Never sleep-then-check
     turns.
   - **green, mergeable, approved or no review required** → `green`. Merge only if the user or
     foreman said this PR is `merge auto`, and never into the production branch.
3. Commit fixes with `scripts/commit.sh` (style once, one concern per commit); push without force
   unless the rebase rule above allows it.

## When a PR doesn't get green

Tend fixes red PRs itself; it hands a PR back only when it hits something it must not decide:

| Situation | Card (foreman launched you) | Without foreman |
|---|---|---|
| Red twice after real fixes, or a conflict it can't resolve safely | `state=blocked note=<why>` | `needs you <url>: <why>` |
| A decision the user owns (scope, API, data, security) | `state=needs_decision` with question, options, recommendation, `impact=high` | `needs you <url>: <question>` |
| 3 review rounds used, or a force push it isn't allowed to do | `state=blocked note=<why>` | `needs you <url>: <why>` |
| Green | `state=pr_open` (or `ready` for manual merge), `ci=green` | `green <url>` |
| Merged / closed | `state=merged` / `state=dropped` | `merged <url>` / `closed <url>` |

Foreman picks the card up on its next wake and escalates it to the user with the others; tend
moves on to the next PR instead of waiting.

## Issues (scope `issues` or `all`)

For each new issue with the label, apply the acceptance test: it targets this repo, asks for a
concrete change, and the direction is settled (quote the lines that show each). Accepted →
write a task file (forge `TASKS.md` format, `Status: todo`) to
`~/.agents/plans/<repo>/inbox/` and add one line to the issue ("queued for an agent"). Not
accepted → leave it alone. Report the queued ones: on the card's `note`, or one line each at the
end (`queued <issue-url> → <task file>`). Building them is foreman's job (`/foreman <inbox dir>`).

## End

One line per PR or issue, nothing else:

```
merged <url>
green <url>
closed <url>
needs you <url>: <why, one line>
queued <issue-url> → <task file>
```
