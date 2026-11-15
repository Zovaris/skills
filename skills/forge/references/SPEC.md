# Spec

## Spec — `spec.md` in the task dir (`references/TASKS.md` says where)

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

## Tasks

Split the spec into tasks, choose where they live and how to run them: `references/TASKS.md`.
