# Docs, ADRs and memory

Files are created only when there is something to write in them.

| What | Where | Who reads it |
|---|---|---|
| Domain terms | `docs/GLOSSARY.md` | everyone, phase 0 |
| Hard decisions | `docs/adr/NNNN-<slug>.md` | phase 0 when relevant |
| Specs and tickets | `docs/specs/<slug>/` | build, review |
| Judgement rules for agents | `docs/agents/STANDARDS.md` | standards reviewer |
| Mechanical rules | lint rules, hooks, scripts | CI, hooks |
| Facts about the user, their preferences | the harness's memory | every session |

The agent instructions file (AGENTS.md, CLAUDE.md…) stays short: commands, and pointers to the
files above.

## init

Create `docs/adr/` with `0000-record-decisions.md` (status accepted: we use ADRs), an empty
`docs/GLOSSARY.md` header, and a pointer block in the repo's agent instructions file (AGENTS.md
if none exists). Run `scripts/stack.sh` and offer to add its commands there.

## Glossary

`**Term** — one-sentence meaning in domain language. _Not:_ synonyms we avoid.` One line per
term, alphabetical, no implementation detail. Update inline the moment a term is settled.

## ADR

Write one only when all three hold: **hard to reverse**, **surprising without context**, and a
**real trade-off** was made. Otherwise a line in the spec's Decisions is enough.

`scripts/adr.sh "<title>"` creates the next numbered file:

```markdown
# NNNN · <title>
Status: proposed | accepted | superseded by NNNN
Date: YYYY-MM-DD

<Context and decision in one or two paragraphs: what forced the choice, what we chose.>

## Considered options
<only if useful: option — why not>

## Consequences
<only if useful: what gets easier, what gets harder>
```

Superseding: new ADR, then set the old one's status line. Never edit an accepted ADR's decision.

## Retro

From the session just finished, list lessons and route each:
- Same mechanical mistake twice → an automated check (lint rule, hook, `stack.sh`-level script).
- Judgement call the reviewer should enforce → one line in `docs/agents/STANDARDS.md`.
- About the user or how they work → the harness's memory (one fact per entry).
- About the project → the right doc above.
- Not worth keeping → drop.
Show the list with destinations; write what the user accepts.
