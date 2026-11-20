# 0008 · Agents per speed are set by trial evidence

- Status: proposed
- Date: 2026-11-20

## Context and Problem Statement

Two trials measured real cost (`docs/trials/2026-11-trial.md`, a sandbox; `docs/trials/2026-11-trial-2.md`,
five fixes in `Zovaris/claude-mods`). Every subagent costs a floor of ~55k tokens on a toy repo
and ~73k on real code, whatever its prompt; skill text is a few thousand. In trial 1 a normal
run cost ~219k with four agents and a full run ~497k with nine, and most findings came from one
agent per run. Trial 2, after the changes below, ran normal at 114–150k with two agents, and
those two still found real bugs in 4 of 5 tasks.

## Decision Outcome

Cost is controlled by how many agents run, so each one has to earn its place with findings in a
trial:
- At `normal`, spec-check and standards run as one reviewer; one second look per round covers
  every fixed finding; the builder check runs only for specs over 8 criteria or with open
  questions; regression runs only for a reported bug with a repro.
- Further cuts (one adversary at full for a pure function, security at full only for a risky
  diff) wait for a trial with a planted bug, so a cut is never taken on "found nothing" alone.
- Each trial's report lives in `docs/trials/`; this ADR is updated, not duplicated, when one
  changes the agent set.

## Consequences

- Good: normal costs about a third less with no finding lost in trial 2.
- Bad: one reviewer reading both files may weigh standards less; the next trial checks it with a
  planted standards break.
