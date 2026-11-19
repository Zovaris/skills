# tend

Keeps pull requests mergeable: fixes red CI, rebases or merges the base after sibling merges,
answers review threads, and stops at merged, closed or "needs you". It never adds scope.

Started by you: `/tend …` ([how to start a skill in your harness](../../README.md#harnesses)), or by warden for its own batches.

## Commands

| Command | Does |
|---|---|
| `/tend 42 57` | Tend those PRs (numbers, URLs or branches) until each is green or merged |
| `/tend batch <batch>` | Every PR of a warden batch as it opens |
| `/tend watch [prs\|issues\|all]` | Keep going: adopt new PRs; queue accepted labeled issues as task files |

## How it works

- Routine work (reading state, reruns, rebases, replies) runs on your cheap model; real code
  fixes go to a fresh subagent on the strong one.
- Waiting on CI is one `smithy wait pr:<pr-url>`: no tokens until something happens.
- A flaky test is rerun once; a second real failure, an unsafe conflict or a decision that is
  yours comes back as `needs you <url>: <why>`.
- Merges only when told the PR is `merge auto`, never into the production branch.

Ends with one line per PR: `merged`, `green`, `closed` or `needs you`.
