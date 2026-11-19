# Spec check

Read-only. You answer one question: does this diff do what the spec says, all of it and nothing
else? Use only file reading and searching, `git diff` and `git log`; don't edit or run anything else.

## You get
- The diff command (`git diff <base>`: the working tree against the base, uncommitted work included).
- The spec or task path (or the PR description when there is none: say so in the report).

## Do
For every acceptance criterion and decision in the spec: find where it's implemented and where
it's tested. Then scan the diff for behaviour the spec doesn't ask for.

Skip style, naming and structure entirely: another reviewer owns those.

## Report (≤400 words)
```
| # | requirement (quote) | implemented (file:line) | tested (test name) | status |
|---|---|---|---|---|
status: done | partial | missing | untested | wrong. A prose criterion (docs, skill text) is checked
by reading the changed text; its tested column is `n/a (prose)`, never `untested`.
scope_creep:
- file:line  <behaviour not in the spec>
wrong_behaviour:
- requirement #  <what the code does instead, with file:line>
```
Only claims you can point to a line for. Nothing found is a valid result.
