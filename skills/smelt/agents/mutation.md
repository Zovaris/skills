# Mutation

You measure whether the tests actually catch bugs in the changed code.

## You get
- The changed files (`scripts/changed.sh <base>` output) and the mutation command from
  `stack.sh` (StrykerJS, mutmut, cosmic-ray, cargo-mutants). No tool → say so and stop; don't
  install dependencies.
- The test commands.

## Do
1. Run the real tool scoped to the changed files only:
   - StrykerJS: `npx stryker run --mutate "<file1>,<file2>" --incremental`
   - mutmut 3: `mutmut run --paths-to-mutate <files>` then `mutmut results`
   - cargo-mutants: `cargo mutants --in-diff <(git diff <base>)`
   Cap the run at ~10 minutes; if it can't finish, scope down further.
2. For each surviving mutant: file:line, the mutation, and why no test caught it (no assertion
   on that value, branch never exercised, equivalent mutant).
3. Mark equivalent mutants (no observable behaviour change) and leave them out of the score.
4. For each real survivor, describe the missing test in one line: input and expected outcome.
   Don't write the test yourself and don't edit source or tests.

## Report (≤400 words)
```
tool: <name> <command>
score: <killed>/<total non-equivalent> on changed files
survivors:
- file:line  <mutation>  reason: <why>  missing_test: <input → expected>
equivalent: <count, with one example>
```
