# Changelog

One version for the whole repo, tagged `vX.Y.Z` (semver). Every change to a skill lands under
**Unreleased** first and moves into a version when it is tagged.

## Unreleased

### CLI
- Windows launcher: falls back to `curl.exe` with timeouts when `gh` is missing, and a failed
  download prints `smithy: can't download v<version> (<asset>): <reason>` with exit 3; a CI job
  runs it on Windows.
- Windows launcher: the SHA-256 read from `certutil` skipped the hash line, so every install
  failed with "checksum mismatch"; it now reads the hash.
- `smithy cleanup` removes a branch whose commits already landed under new hashes (a rebase
  merge), instead of keeping it as unpushed.
- Every command: `-h`/`--help` anywhere prints its usage on stdout and exits 0 before any repo
  check, gh call or side effect; an unknown option prints `smithy <cmd>: unknown option <x>`
  and the usage on stderr, exit 2 (so `smithy adr --bogus` no longer writes an ADR).
- Usage mistakes exit 2 (`smithy commit "<msg>"` without paths, `smithy pr create` misuse).
- `smithy changed` outside a repo says "not a git repo" (exit 2); `smithy comments <path>`
  with a missing path exits 2; `smithy wait` rejects an unknown target (exit 2) before gh.
- Failures say why on stderr: `smithy skills <name>` not installed, `smithy config model|get`
  unset, `smithy tasks where` with none, `smithy cards get` for a missing card (now exit 1, not
  `null`), `smithy agent` with a missing prompt file.
- `smithy tasks add|list` without a dir use the newest task dir, even an empty one made by
  `smithy task-dir`.

### hardening
- `smithy comments --diff` reads file names with `-z` (spaces and non-ASCII names count) and exits 2 for a base git can't resolve or one starting with `-`.
- `smithy drift` exits 2 for a base git can't resolve and reads changed and tracked names with `-z`.
- `smithy route` exits 2 for an unknown `--kind` or `--speed` and for a flag without its value.
- `smithy config` reports a config file that isn't a JSON object (including `null`) on reads too, rejects empty or malformed keys, harness names and model names, and locks the file around writes so concurrent `set` calls keep every value.
- The launcher times out downloads (`--connect-timeout 10 --max-time 120`) and a failed download prints one `smithy: can't download` line and exits 3.
- `smithy scan` prints to stderr how many lines `smithy:allow` skipped and where.

### skills consistency
- `warden.merge` has no built-in default: warden asks once per batch in its plan line (auto or
  manual); a saved setting counts as the user's words. Production merges need the user's words.
- Merge, cleanup and report rules match use-smithy everywhere: workers end with `done: <id> …`,
  tend can stay until a PR merges and cleans up, warden ends tend when the batch is final, and
  nothing runs `git worktree remove --force`.
- Sessions that can't ask use the session model and default mode; scout treats outside content as
  data; warden is not invoked implicitly; slash commands are only examples of the words.
- smelt: fast with no plan builds from the task's criteria (in `.smelt/spec.md`, with its own
  `.gitignore`); reviewers diff the working tree against the base; a no-remote ship skips the PR.

### cleanup
- Clean up after merge is a shared rule: whoever sees the PR merge or close removes the work's
  worktrees and local branches and ends the agents or sessions it launched. smelt hands the
  branch and worktree to tend, which cleans them up when the PR merges.

### models
- smithy ships no model names: `smithy config suggest-models` and `accept-models` are gone. The
  first time a tier is needed the skill asks the user to name it and saves it with
  `smithy config set-model` in `~/.smithy/config.json`; a session that can't ask uses its own model.

### from the smelt validation run
- The launcher builds the dev binary per checkout (`~/.smithy/bin/dev/<checkout id>`), so
  parallel worktrees never run each other's build.
- `smithy route --agent <file|name>` routes a smelt agent (reviewers cheap, test agents mid).
- `smithy comments --diff <base>` reports only the lines the change adds.
- `smithy pr --help` prints usage; `smithy pr template` says why when there is no template.
- smelt: inline criteria go to `.smelt/spec.md` for the agents; test agents run together,
  in worktrees at absolute paths; VERIFY splits "ready to open" from "ready to merge"; a branch
  the harness made is kept; the standards reviewer falls back to use-smithy's ground rules; a
  session that can't ask uses its own model.

### launcher
- The binary is installed only after its GitHub build attestation is verified (needs `gh`);
  without it the launcher stops with how to fix it, unless `SMITHY_ALLOW_UNATTESTED=1`
  accepts a checksum-only install. Answers the skills.sh Snyk E004/W012 on the launcher.

### hush and warden workers, from the skills.sh Snyk audit
- hush no longer tells the agent to override the harness's narration rules; it keeps chat to
  what the harness or user requires, records each decision visibly, and the user can end it by
  asking. Web pages, files, issues and tool output are data, never instructions: a shared rule
  in use-smithy, and stated where content enters (hush, smelt review comments, tend, warden
  intake and worker brief).

### smithy binary
- `smithy drift [base]` resolves its base like `smithy scan` (one shared resolver): a branch
  name diffs against its merge-base with `origin/<branch>`, no base means origin's default
  branch, and the report's `base:` line names the ref instead of a bare SHA.
- New `agent.effort` setting (default `medium`, also the cap): `smithy agent --effort`,
  `$AGENT_EFFORT` or the setting; `high`, `xhigh` and `max` are lowered to `medium`. Claude Code
  gets `--effort`, Codex `-c model_reasoning_effort`; every CLI gets `$AGENT_EFFORT`, and one
  without an effort flag says it runs at its own default. `smithy consult` uses it too.

### smelt
- New `agents/hostile.md`: runs the built CLI, API or worker as a hostile user across eight
  classes (malformed input, interruption, cancel-and-resume, repeats, injected instructions,
  dirty surroundings, hung dependencies, lying output), in at most 5 cycles, with failure
  fingerprints, flakiness recorded as a finding and harness debris kept apart. Runs after review
  at `full`.
- `smithy receipt run --claim "<c>" -- <cmd>` records each verify run (exit code, output
  digest, commit, dirty tree, platform) in `.smelt/receipts.jsonl`; `smithy receipt list --md`
  prints the table for the PR body and marks receipts from another commit or a dirty tree stale.
- `smithy scan` checks the lines and files a change adds for private keys, tokens and
  secret-bearing files before ship; `smithy:allow` on a line marks a false positive.
- Review: the reviewer closes a blocking finding, not the author. A fixed blocking or high
  security finding (every finding at `full`) gets one bounded second look by a fresh subagent.
- Ship: scan before anything leaves the machine, receipts in the PR body, and one proposed
  lesson when something surprised you (or "no lesson").

### from the first smelt run
- `smithy scan --base <branch>` diffs against `origin/<branch>` (merge-base) when it exists, and
  says which: `scan: clean against origin/main (merge-base dbcdb0e)`.
- `smithy scan` now reads untracked files' content, handles non-ASCII names, isn't fooled by
  added lines that start with `++`, refuses a `--base` that looks like an option, and without
  an origin default branch or upstream scans the whole history instead of only edits.
- Receipts: tokens in a recorded command are masked in `list`; a write failure keeps the
  command's exit code; a cut last line no longer swallows the next receipt.
- Receipts: one taken with (or followed by) uncommitted changes shows as `dirty`, not `stale`; commands keep their
  quotes (`sh -c 'bun run test'`); `.smelt/` writes its own `.gitignore`; `list` says how many
  receipts from other commits it hid.
- `smithy config set agent.effort high` saves `medium` and says so; other values than `low` or
  `medium` are refused. New `smithy config unset [--repo] <key>`. `set` refuses a config file
  that isn't JSON instead of overwriting it.
- `smithy stack` gives `bun run test` (the package's script), not `bun test` (Bun's runner).
- `smithy wait --help` prints its usage; `smithy verify` usage says `<repo-dir>` is a local path.
- `smithy verify` says `draft` (exit 3) for a draft PR that is otherwise green, instead of
  `pending`; `checks` reads `green`/`red`/`pending`/`none` in `verify`, `pr-state` and `wait`
  alike (was `pass`/`fail` in the first two).
- `smithy verify` takes a PR URL and exits 2 when it belongs to another repo than the checkout's
  origin; tend and smelt pass URLs to `verify` and `wait`, so a bare number can't hit the wrong PR.
- tend reads the PR state before any worktree, and only uses the main checkout when the PR
  branch is already there and clean.
- smelt: agents work silently and send questions up; ship hands the PR to a tend subagent when
  tend is installed; review and scan use `origin/<base>`; test-agent worktrees start from your
  commit and their files are folded into the repo's tests, never committed as is; another review
  look only when the fix pays for it; agents that didn't apply are listed in the PR body.

### skills, from a best-practice review
- Every skill can be run by an agent (no more `disable-model-invocation`); warden still asks for a
  yes because it costs sessions. Docs no longer assume slash commands.
- Merges: only the session that talks to the user decides; tend and workers merge on `merge
  auto`; a production merge needs the user's explicit yes, up front or asked at green.
- Agents launched by smelt get a report contract (silent, `done:`, questions under `Question:`).
- warden acts on the verdicts `smithy verify` really prints; tend keeps one review-round counter
  and handles `smithy wait` exit codes; smelt's ship phase moved to `references/SHIP.md`.

### tests
- Go unit tests for cards, config, harness, ghx, tasks, wait and warden (each 96–100%); total
  Go coverage 66%.
- CI runs `go test -race`, writes per-package coverage to the job summary and fails under 60%.
- Fix: `smithy wait prs|issues` no longer misses the first new item when the first snapshot was
  empty.
- `smithy doctor` looks up skills in-process instead of running itself once per skill.

## v0.8.0 — 2026-11-16

### smithy (breaking)
- The repo is now `Zovaris/smithy` (GitHub redirects the old name): install with
  `npx skills add Zovaris/smithy -g`.
- The collection is now **smithy** and the generic names are gone: playbook → `use-smithy`,
  forge → `smelt`, foreman → `warden`, docs → `ledger`, silent → `hush`, direct → `simple`;
  `scout` and `tend` stay. Reinstall, and use the new commands (`/smelt`, `/warden`, `/hush`…).
- Settings, plans, batches and tend state live in `~/.smithy/` (`$SMITHY_HOME`) and
  `<repo>/.smithy/config.json`; the first run moves the old `~/.agents/` files
  (`config.sh migrate` by hand). The repo's old `.agents/config.json` is still read until moved.

### smithy binary
- One Go binary, `smithy`, replaces the shell and Node helpers: `smithy config`, `harness`,
  `names`, `tasks`, `cards` (warden status cards), `wait` and `status`. Same commands, flags,
  output and exit codes as the scripts they replace; the old script tests now run through it.
- Skills ship a launcher (`scripts/smithy`, `smithy.cmd`) that downloads the binary for the
  platform once from the GitHub release (gzipped, ~1.4 MB), verifies its checksum and build
  attestation, and caches it in `~/.smithy/bin/<version>`; in a source checkout it builds from
  source instead. `SMITHY_BIN` overrides.
- Every helper is now a `smithy` command; no skill ships bash, Node or Python any more (only
  the launcher). New since the first cut: `commit`, `pr`, `cleanup`, `verify`, `pr-state`,
  `agent`, `consult`, `route`, `skills`, `setup`, `stack`, `changed`, `guard-tests`,
  `task-dir`, `adr` (one for smelt and ledger), `search`, `comments`, `drift`, `doctor` and
  `wait-turn`; tend's and warden's `watch.sh` are `smithy wait watch[:scope]` and
  `smithy wait batch:<name>`. Runtime needs drop to git and gh (no jq, node or python3).
- Small differences from the scripts: messages say `smithy <cmd>:`; an empty check conclusion
  counts as pending; cleanup handles worktree paths with spaces; `$AGENT_ARGS` is split with
  quotes but no shell expansion; `setup block add` is idempotent; search cuts long lines by
  characters, not bytes.
- CI: `check` on pull requests and main (gofmt, vet, tests, cross builds); `release` on `v*`
  tags (binaries, checksums, provenance attestation, GitHub release from the CHANGELOG).

### waiting
- `smithy wait`: one zero-token waiter for `pr:` (checks finished green/red with the failed
  names, merged, closed, conflict, review, comment, push), `run:`, `branch:`, `prs`, `issues:`
  and `batch:` targets, any mix in one call. Already-finished checks return at once; a bad
  target fails fast. Settings `watch.events`, `watch.every`, `watch.max`.
- tend's and warden's `watch.sh` are presets over it; smelt, warden workers and tend wait on it
  instead of sleep loops.

### naming
- `names.sh`: branches `<type>/<key>-<slug>` (key: Jira or Linear key, issue number or task
  `NN`) and worktrees `<repo-parent>/worktrees/<repo>-<branch>`, from `git.branch` and
  `git.worktree`. smelt, warden and tend use it; tend no longer depends on a branch prefix.

### tasks
- `tasks.js add` creates the next task file; `tasks.js board [--all]` lists every task list and
  warden batch here or on the whole machine; `/warden status all` shows it.

### use-smithy
- Proposes saving repeated commands and throwaway scripts into `scripts/` with a `SCRIPTS.md`
  index at the end of a task (after scriptify), and checks that index first.

## v0.7.0 — 2026-11-15

### review against skill-authoring best practices
- Shorter descriptions on every skill (what + when, ~170–290 characters).
- foreman split from 237 to 114 lines: intake, state, acting and models moved to references; one defaults table with precedence; contradictions on production merges, `max`, tend launch and model rules resolved.
- forge references no longer chain into each other; duplicated rules and red flags removed; every phase has a done check; one definition of "agent".
- playbook, docs, scout, tend, silent and direct: overlaps and contradictions resolved (ADR test, inline scout runs, `done:` stays English, docs init creates STANDARDS.md); Claude-only wording removed outside harness notes; golangci-lint example on v2.

### decisions
- `consult.sh` moved to `shared/` and ships with forge, foreman and tend. It asks the user's strong model through the CLI of the harness you're in (Claude with no tools; Codex, OpenCode, Gemini, Pi, DeepSeek or Cursor read-only through `agent.sh`) instead of preferring Claude whenever it's installed; `--context <file>` adds a short excerpt. Tested live through OpenCode.
- forge (`build all`, `/silent`), tend and playbook use the same rule as foreman: low impact decide, medium `consult.sh`, high the user; every decision is logged.

### model routing
- `route.js` picks a model tier per task from the task itself (risk, difficulty, size, kind, speed): cheap, mid or strong, mapped to the user's models for the current harness. Nothing is tied to the session's model.
- `config.sh suggest-models` / `accept-models`: where a harness has stable tier aliases (Claude: haiku, sonnet, opus) the agent proposes them in one line and saves them on a yes; elsewhere it asks for each tier. playbook setup shows the suggestions.
- New `mid` tier (`config.sh set-model mid <name>`) and `foreman.worker_model` (`route` by default, `session`, or one model name).
- foreman launches each worker on its routed model and shows tier and model in the plan line; forge's `build all` routes implementers and reviewers the same way.

### foreman and silent
- The worker brief carries the silent rules itself, at the top and again before the closing line, and foreman spawns workers with the brief's full text instead of a pointer to the file, so the rules don't fade over a long session.
- `silent` names the narration it forbids ("Now let me…", "Next I'll…") and says the rule lasts the whole session.

## v0.6.0 — 2026-11-15

### shared
- `agent.sh` runs workers unattended on every supported CLI, checked against each harness's docs and source: OpenCode `--standalone --auto` (tested live; without `--standalone` it doesn't work in the current folder), Codex with the git dir writable and network on, Gemini `--approval-mode yolo`, Claude `--permission-mode auto`, plus Cursor (`agent -p --force`), Pi (`pi -p`) and DeepSeek Harness (`dsh headless`). `AGENT_CLI` picks one, `AGENT_ARGS` adds flags. Workers get `FOREMAN_HARNESS` and lose the parent's harness variables; output goes through a file so a CLI that leaves a server running can't hang the caller.
- `harness.sh` detects Pi and DeepSeek Harness and no longer mistakes user settings (`CODEX_HOME`) for a harness; `find-skill.sh` and playbook's setup know every harness's skills folder and global instructions file.
- Codex: `agents/openai.yaml` keeps forge, foreman, silent and tend user-invoked.
- README: per-harness table (skills folder, how to start a skill, how workers run, background wake).

## v0.5.0 — 2026-11-15

### playbook (new)
- Loaded by the agent at the start of software work: lists the installed skills, routes work to them (forge, foreman, docs, scout, tend, silent, direct) and holds the shared rules and red flags.
- `scripts/setup.sh`: status of installed skills and models, and an opt-in pointer block for the user's `AGENTS.md` / `CLAUDE.md`.

### direct (new)
- Short, direct replies with no filler or AI tells; `silent` wins while it runs; code, commits, PRs and docs are written normally.

### docs (new)
- ADRs, glossary, module READMEs, codebase map, doc drift checks, comment policy (API doc comments only) and search over docs and decisions.

### scout (new)
- Read-only investigation with sources on the user's cheap model; reports recommend, never authorize.

### tend (new)
- Keeps open PRs mergeable: CI fixes, rebases after sibling merges, review comments; launched by foreman for its batches.
- Models: routine work on the user's cheap model, code fixes on the strong one; `--model` / `--fix-model` override.
- `watch [prs|issues|all]`: keeps adopting new PRs (default) and can queue accepted labeled issues as task files for foreman, never building them; `scripts/watch.sh` waits without tokens.
- A PR it can't get green comes back to foreman as a `blocked` / `needs_decision` card, or to the user as `needs you <url>: <why>`.

### forge
- `build all`: every task here with one implementer subagent each, per-task review, capped fix loop and a rulings ledger.
- Verify gate (no claim without fresh evidence) on build, test, review and ship; red-flag tables.
- Receiving review, a builder check after the spec, a security reviewer, Files and Interfaces in tasks, baseline test run, a three-way close (PR, merge if asked, keep).
- Delegates `adr`, `init`, context and the ship docs step to the docs skill when installed; fact-finding to scout.

### foreman
- Launches every worker in the user's turn; items that can't start yet wait in their own session on `wait-turn.sh` (new `waiting` state) until their prereqs merge and a slot frees. Batches with dependencies stay autonomous in harnesses that can't start sessions from event turns.
- The watcher wakes only for cards that need the foreman (decisions, stuck, PRs, merged, reported, dropped); `--all` for every change.
- Workers merge `origin/<base>` before opening the PR and before merging; a refused merge ends as `ready note=merge-blocked` and the foreman merges; work found after a merge becomes a follow-up PR (small) or a task file for the foreman to decide.
- `merge auto|manual` and `cleanup auto|ask`, both `auto` by default and stored in `batch.json`; worktrees default to a sibling `<repo-parent>/worktrees/<repo>-<id>`.
- `doctor` suggests allowing `gh pr merge` in Claude Code; `harness.md` documents the event-turn rule and finding a card's session id.
- Scout items follow the scout skill; a tend session keeps the batch's PRs green once workers end.
- Models come from the user's choice per harness (`config.sh`), never hard-coded; `consult.sh` uses the strong one.
- `doctor` checks the companion skills and model settings.

### shared
- Settings: `config.sh` reads `<repo>/.agents/config.json` then `~/.agents/config.json` then defaults; `config.sh list` shows every setting, its value and source; `set --repo` saves per repo. Known settings: models, `tasks.location/commit/ignore`, `foreman.merge/cleanup/max/mode`, `tend.watch/label`.
- `task-dir.sh <slug>`: one place that decides where specs and tasks go; asks `tasks.commit` once per repo and, when specs stay out of git, whether to add `.docs/` to `.gitignore` or `.git/info/exclude`.
- `tasks.js where` also finds `.docs/specs/` (specs kept out of git) and `$FORGE_TASKS_DIRS`; forge reads `tasks.location` / `tasks.commit` (default committed) from the user config.
- `config.sh` (cheap and strong model per harness in `~/.agents/config.json`), `find-skill.sh --list`; `harness.sh`, `verify.sh` moved to `shared/`.
- `tests/run.sh` (offline tests, skill lint) in CI, and `scripts/drill.sh` for live pressure tests against an agent CLI.

### forge and foreman
- `commit.sh`: detects the repo's commit style (commitlint, history: conventional, gitmoji or plain), checks messages and commits exactly the given paths, one concern per commit.
- `pr.sh`: finds the PR template and refuses a body that drops its headings; reuses an open PR instead of opening a second one.
- `cleanup.sh`: removes a finished task's worktree and local branch every time, and refuses to drop unpushed work.
- Shared scripts live in `shared/` and are copied into each skill by `scripts/sync-shared.sh`; CI checks they stay in sync.

### foreman
- Workers turn on their harness's auto-archive when their PR closes, so sessions waiting on a manual merge end on their own.
- A PR closed without merge marks the item `dropped` and ends its worker.
- The foreman ends every finished worker before its final message; `blocked` / `failed` ones stay open for inspection.
- New `/foreman cleanup [batch]`: re-verifies waiting PRs after the batch is over and ends their workers.

## v0.4.0 — 2026-11-15

First tagged release.

### silent
- Runs a task end to end with no talk between tool calls; progress only in the harness's to-do list.
- Ends with one line in English: `done: <where it landed>` (PR, commits, uncommitted changes or an answer); only commits or opens a PR when the task asks.
- Stops only for what is the user's alone, with `blocked: <why>`.

### forge
- Phases with exit gates: brainstorm (why, approaches, design) → grill → spec → task list → TDD → test agents → review → ship → retro.
- Start at any phase (`/forge build`, `/forge test`, `/forge from test`) at three speeds: `fast`, `normal`, `full`.
- Shared task list (`NN-<slug>.md` with `Status`, `Blocked by`, `PR`) on a board, in the repo or in `~/.agents/plans`, managed by `scripts/tasks.js`; `/forge build next` works it one task at a time.
- Independent test agents: adversary, regression, property, mutation, E2E; read-only spec-check and standards reviewers.
- ADRs, glossary and standards docs; optional `guard-tests.sh` pre-edit hook.

### foreman
- Runs one or many tasks in parallel: one silent worker and git worktree per task, each to a PR or a report.
- Takes inline tasks, a task dir, board ids or just an idea (offers to plan it with forge or split it).
- Workers follow forge (`fast` / `normal` / `full`) or plain mode, reading each skill's `SKILL.md` by path.
- Status cards, a zero-token watcher, PR verification, decisions escalated by impact, recovery ladder.
- Harness-agnostic: adapters for Claude Code desktop and CLI, and `agent.sh` for any agent CLI; `doctor` checks only what the detected harness needs.
