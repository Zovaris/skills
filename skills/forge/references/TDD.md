# TDD

## Loop

For each behaviour in the acceptance criteria, in order of the tracer bullet:

1. **Red.** Write one test at an agreed seam. Run that file. It must fail on an assertion that
   names the missing behaviour. An import, syntax or setup error is not red: fix the test.
2. **Green.** Write the least code that passes it. Run the file again.
3. Next behaviour. Never write all tests up front: each test teaches you something.
4. **Refactor** once the slice is green: behaviour unchanged, tests untouched and still green.

Run typecheck every few cycles; the full suite at the end of the task.

## Good tests

- Each test names the production break it catches (in its name or a one-line comment).
- Expected values are hand-derived literals, never recomputed the way the code computes them.
- Test behaviour through the public seam, not private functions or call order.
- Mock only system boundaries (network, clock, randomness, filesystem, third-party APIs). Mock
  data is complete and realistic. Never assert that a mock exists or was merely called when the
  result could be asserted instead.
- One reason to fail per test. Arrange / act / assert reads top to bottom.
- Bug fix → the regression test reproduces the bug first and fails on the unfixed code.

## Anti-patterns to refuse

- Tests that mirror the implementation (would pass for any code that makes the same calls).
- Tests that pass on the first run (they test nothing new; check by breaking the code).
- Editing a test during green. If a test is wrong, stop, say why, fix it as its own red step.
- `skip`, `only`, `xfail`, loosened assertions or snapshot updates to get green.

## Red flags

| Thought | Reality |
|---|---|
| "Too simple to need a test" | Simple code breaks too, and the test takes a minute. |
| "I'll write the tests after" | Tests written after pass on the first run and prove nothing. |
| "I already wrote the code, I'll keep it as reference" | Code before its test gets deleted; start from red. |
| "The test is wrong, I'll adjust it to green" | Stop. Say why it's wrong; fix it as its own red step. |
| "Mocking this makes it easier" | Mock only system boundaries; otherwise you test the mock. |
| "Just this once, skip the failing test" | Skipped tests are deleted tests. Fix or report. |

## Optional hard guard

`scripts/guard-tests.sh` is a PreToolUse hook that blocks edits to test files while
`.forge/green` exists. `touch .forge/green` before writing code, remove it to write the next test.
Install instructions are in the script header.
