# Spec and tickets

## Spec — `docs/specs/<slug>/spec.md`

Explore the code first. Propose the test seams (public entry points where behaviour is observable;
ideally one, as high-level as possible) and confirm them with the user before writing.

```markdown
# <Feature>
Status: draft | agreed | done

## Problem
<who hurts, how, in the user's words where possible>

## Solution
<the behaviour, not the implementation>

## User stories
- As a <role>, I <do>, so that <outcome>.

## Acceptance criteria
- [ ] <observable, testable statement>

## Decisions
<settled choices and why; link ADRs. No file paths.>

## Test seams
<where tests drive the system; what is mocked (only system boundaries)>

## Out of scope
- <explicitly excluded>
```

## Tickets — `docs/specs/<slug>/NN-<slug>.md`

- **Tracer bullets:** each ticket is a thin vertical slice through every layer that is demoable
  on its own, not a horizontal layer.
- **Prefactor first:** "make the change easy, then make the easy change". Wide renames or
  migrations use expand → migrate → contract tickets.
- Each fits one fresh context window; split if a ticket needs more than ~1 day of human work.
- Show the list (title, one line, blocked-by) and wait for approval before writing files.

```markdown
# NN · <title>
Blocked by: <NN, NN | none>
Spec: ./spec.md

## What
<one paragraph>

## Acceptance criteria
- [ ] <from the spec, narrowed to this slice>

## Notes
<seams, risks, files likely touched>
```

Independent tickets can run in parallel with `/foreman`, one ticket per line with its path.
