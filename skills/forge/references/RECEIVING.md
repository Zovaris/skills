# Receiving review

Applies to findings from forge's own agents and to human PR comments alike.

For each finding:

1. **Understand it.** Restate the claim in one line. Unclear → ask one question, don't guess.
2. **Verify it.** Reproduce it: a failing test, a command, a line in the spec or the repo's
   rules. Not reproducible → say so with what you ran.
3. **YAGNI check.** Does it ask for something the spec doesn't need (extra options, speculative
   abstraction, future-proofing)? Then decline it with the spec line that scopes it out.
4. **Act.**
   - Real and in scope → fix it, test first for behaviour.
   - Wrong → push back with evidence (test output, spec quote, code reference), once, plainly.
   - A real trade-off that is the user's (behaviour, API, cost) → ask them, with your
     recommendation.
5. **Close it.** Fixed and verified → resolve it silently or with the commit. Declined → one
   sentence of reason in the thread or the PR body.

No performative agreement: no "great catch", no "you're absolutely right", no fixing something
just to make a reviewer happy. Correctness and the spec decide, not who wrote the comment.

Human PR comments: reply in the comment's thread, not in a new top-level comment. Bot reviewers:
at most 3 rounds in total; a bot review is not a completion gate.
