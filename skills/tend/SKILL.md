---
name: tend
description: "Keeps someone else's PRs mergeable: fixes red CI, rebases or merges the base, answers review comments, and stops at merged, closed or needs-you. Use for open PRs (URLs or branches), a warden batch, or watch mode; smelt and warden start it after opening PRs."
argument-hint: "<pr-url|number|branch> [...] | batch <warden batch> | watch [prs|issues|all] [--label <l>] [--model <m>] [--fix-model <m>] [--card <batch> <id>] [--max-hours <h>]"
---

# tend

You look after PRs someone else opened (a person, a smelt session, a warden worker) until they
can merge. You fix what blocks them; you don't add scope. Work silently (the `hush` skill's
rules if installed): no talk between tool calls, one line per PR at the end.

`smithy <command>` in this skill means `<skill-dir>/scripts/smithy <command>` (`<skill-dir>` is this file's folder); run it by that path, nothing needs to be on PATH.

| Command | Does |
|---|---|
| `smithy pr-state <pr>` | Compact PR state: checks, mergeable, review, unresolved threads, behind |
| `smithy verify <repo-dir> <branch> [pr-url]` | Pushed head, checks, mergeable; `draft` (exit 3) when all green but still a draft, `pending`/`red` exit 1 (`<repo-dir>`: the local checkout, `.` for here; a URL that isn't that checkout's repo exits 2) |
| `smithy commit` | Commits in the repo's style |
| `smithy names` | Worktree path for a PR branch |
| `smithy wait <target>…` | Zero-token wait on GitHub: `pr:<url>` (a bare number means the current checkout's repo), `run:<id>`, `branch:<name>`, `prs`, `issues:<label>` |
| `smithy wait watch[:prs\|issues\|all]` | Watch mode: wait for new or updated PRs / labeled issues (scope from `tend.watch`) |
| `smithy consult` | One tool-less call to the user's strong model for a technical choice |
| `smithy config` | The user's models and tend settings |
| `smithy agent` · `smithy harness` · `smithy route` | Run a fix subagent on any CLI (when the harness has no subagent tool), detect the harness, pick a tier |

## Input

- PR urls, numbers or branch names: one loop per PR, then stop.
- `batch <name>`: the items of that warden batch, each as it reaches `pr_open` or `ready`
  (`smithy cards board <name> --json`). Warden starts you with the workers,
  so between PRs wait with `smithy wait batch:<name>`; stop when every item is
  final (merged, dropped, reported).
- `watch [scope]`: keep going. Tend the PRs that match, then wait with `smithy wait watch[:scope]` and
  adopt what appears, until the user stops it or `--max-hours` (default 8) passes. Scope:
  - `prs` (default): open PRs by the user (warden and smelt open them as the user) or with
    `--label`.
  - `issues`: new issues with `--label` (default `agent`); see "Issues" below. Never builds them.
  - `all`: both.
  The default scope is `smithy config get tend.watch` when set, else `prs`.
- `--card <batch> <id>`: when warden launched you, mirror your state on that card
  (`smithy cards set <batch> <id> key=value…`; cards are shared through `~/.smithy/warden`).

## Models

- Routine work (reading state, reruns, rebases, merging the base, replying to comments) runs on
  `--model`, else `smithy config model cheap`. Exit 3 means unset: propose `smithy config
  suggest-models` and save on a yes (`smithy config accept-models`), or ask for the cheap model when
  there are no suggestions (under hush or when warden launched you, use the session
  default instead of asking).
- Code fixes (a real CI failure, a review comment that asks for a change) go to a fresh
  subagent on `--fix-model`, else `smithy config model strong`, else the session default, with only
  the failing output, the PR diff and the comment. You review its diff before committing.

## Loop, per PR

Read the state first; a worktree is only for changing code. When a step needs one, use the PR
branch's existing worktree if `git worktree list` shows one. If the branch is checked out in the
user's main checkout, work there only when it is clean and on that branch; otherwise stop with
"needs you" rather than switching it. Else add one at `smithy names worktree <pr-branch>` (never
inside the repo). Then repeat:

1. `smithy pr-state <pr>` → `{state, checks, mergeable, review, unresolved, behind}`; `checks` is
   `green`, `red`, `pending` or `none`, the same words `smithy wait` and `smithy verify` use.
2. Act on the first thing that applies:
   - **merged / closed** → stop this PR; remove the worktree you created.
   - **checks red** → `gh run view <run> --log-failed`. Same test passes on a plain rerun and
     nothing in the diff touches it → flaky: rerun once (`gh run rerun <run> --failed`) and note
     it. Otherwise it is a real failure: hand it to the fix model, failing test first when it is
     a bug, and push the fix. Red again after a second real fix → "needs you".
   - **conflicting or behind base** → follow the repo: rebase if its history is linear (no merge
     commits on the base in `git log --merges -5`), else merge the base. A rebase needs a force
     push: `--force-with-lease` only on branches of a warden batch you were given, or of a PR the
     user asked you to tend by name; on anyone else's branch, merge the base instead or stop
     with "needs you". Conflicts you can't resolve from both sides' intent → "needs you".
   - **unresolved review threads** (human or bot) → `references/RECEIVING.md`. At most 3 rounds
     per PR; the count lives in the card's `review_rounds` (`smithy cards set <batch> <id>
     review_rounds=<n>`); without a card, in `~/.smithy/tend/<owner>-<repo>-<n>.rounds`.
   - **checks pending** → `smithy wait pr:<pr-url>` in the background (foreground where the
     harness can't wake on exit); it returns one line when checks finish, the PR merges or closes,
     or a review lands. Exit 0: read the state again. Exit 4 (heartbeat): wait again. Exit 2 or 3
     (bad target, gh missing or signed out): "needs you". Never sleep-then-check turns.
   - **green, mergeable, approved or no review required** → `green` (`smithy verify` says `draft`
     for a draft PR: report `green (draft)` and leave it a draft). Merge only if whoever launched
     you said `merge auto`, never a draft, and into the production branch only when the launch
     says the user approved it (use-smithy: merges); otherwise stop at green.
3. Commit fixes with `smithy commit` (style once, one concern per commit); push without force
   unless the rebase rule above allows it.

## When a PR doesn't get green

Tend fixes red PRs itself; it hands a PR back only when it hits something it must not decide:

| Situation | Card (warden launched you) | Without warden |
|---|---|---|
| Red twice after real fixes, or a conflict it can't resolve safely | `state=blocked note=<why>` | `needs you <url>: <why>` |
| A technical choice inside the PR's scope (which fix, which approach) | settled with `smithy consult` (the user's strong model), noted in the commit or reply; `ESCALATE` → next row | same |
| A decision the user owns (scope, API, data, security) | `state=needs_decision` with question, options, recommendation, `impact=high` | `needs you <url>: <question>` |
| 3 review rounds used, or a force push it isn't allowed to do | `state=blocked note=<why>` | `needs you <url>: <why>` |
| Green | `state=pr_open` (or `ready` for manual merge), `ci=green` | `green <url>` |
| Merged / closed | `state=merged` / `state=dropped` | `merged <url>` / `closed <url>` |

Warden picks the card up on its next wake and escalates it to the user with the others; tend
moves on to the next PR instead of waiting.

## Issues (scope `issues` or `all`)

For each new issue with the label, apply the acceptance test: it targets this repo, asks for a
concrete change, and the direction is settled (quote the lines that show each). Accepted →
write a task file (smelt `TASKS.md` format, `Status: todo`) to the inbox dir, which follows the
user's task settings (`smithy config get tasks.location|tasks.commit`): `~/.smithy/plans/<repo>/inbox/`
when local, else `docs/specs/inbox/` (committed) or `.docs/specs/inbox/` (not committed); then
add one line to the issue ("queued for an agent"). Not
accepted → leave it alone. Report the queued ones: on the card's `note`, or one line each at the
end (`queued <issue-url> → <task file>`). Building them is warden's job (`/warden <inbox dir>`).

## End

One line per PR or issue, nothing else:

```
merged <url>
green <url>
closed <url>
needs you <url>: <why, one line>
queued <issue-url> → <task file>
```
