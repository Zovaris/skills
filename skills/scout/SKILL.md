---
name: scout
description: Read-only investigation that answers one question with cited sources and changes nothing. Use when asked "can we do X", "what does library Z do", "how does this code work" or "compare A vs B" before deciding or building. Not for past project decisions (docs).
argument-hint: <question> [--out <report path>]
---

# scout

Answer one question from primary sources and stop. A scout never edits code, config, git state
or anything outside its report. A report may recommend an implementation; it never authorizes
one.

Scripts and files are relative to `<skill-dir>` (this file's folder).

## 1 · Frame

Restate the question in one line and name what would settle it (a file, a doc page, a
benchmark, a changelog entry). Split a compound question into at most 3 sub-questions. If the
question is really a decision for the user ("which should we use?"), the report ends with a
recommendation and the trade-off, not with the choice made.

## 2 · Pick the model

`scripts/config.sh model cheap`:
- prints a name → use it.
- exit 3 → propose `scripts/config.sh suggest-models` and save on a yes (`config.sh
  accept-models`); with no suggestions, ask "Which cheap model should scouts use in this
  harness?" and save it with `config.sh set-model cheap <name>`. Under `/silent`, don't ask: use the harness
  default and say so in the report.

Use the strong model (`config.sh model strong`) only when the user asks or the question is about
security, money or data loss.

## 3 · Investigate

Run `references/INVESTIGATOR.md` as a **subagent** on that model, with the question, the
sub-questions and the repo path filled in:
- harness subagent tool with a model parameter, read-only tools; or
- `scripts/agent.sh --readonly --model <m> <prompt-file>` (any agent CLI).

Doing it inline is fine when the answer is one or two lookups; inline runs on the session's
model, so say so in the report. Either way:
- Sources, best first: the code (`path:line`), official docs, changelogs and release notes,
  issues and PRs, then everything else. Every claim gets a link or a `path:line`.
- Run read-only commands only (`rg`, `git log`, `gh api`, `--help`, a REPL import). No installs,
  no writes, no network calls that change state.
- Disagreeing sources: report both and which is newer.

## 4 · Report

Fill `references/FORMAT.md`. Destination:
- default: the chat;
- `--out <path>` (foreman passes `<batch-dir>/<id>/report.md`, forge passes its task dir): write
  the file there and reply with its path and the one-line answer.

**Done:** the question has an answer (or "unknown" with what would settle it), every claim has a
source, and nothing outside the report changed.
