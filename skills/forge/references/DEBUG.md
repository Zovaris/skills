# Debugging

Phases with gates; don't skip ahead.

1. **Reproduce.** Get one fast command that fails on this exact bug, every time. No theories
   until it exists. Can't reproduce → collect what's missing (logs, input, env) and say so.
2. **Shrink.** Make the repro as small and fast as possible (smallest input, single test file).
3. **Hypothesize.** Write 3–5 ranked hypotheses, each with a prediction you can test
   ("if it's the cache, clearing it makes the repro pass").
4. **Probe.** Test the top hypothesis with the cheapest probe. Tag every debug log line
   (`[forge-debug]`) so cleanup is a grep. Update the ranking after each probe.
5. **Fix.** Turn the repro into a regression test at the right seam; it must fail. Fix the root
   cause, not the symptom. Test green, full suite green.
6. **Clean.** `grep -rn "\[forge-debug\]"` returns nothing. Note the root cause in the PR body.
   A cause that will bite again (bad pattern, missing guard) → propose a check in retro.

Then run `agents/regression.md` against the fix and continue with review.
