# Scout report format

```markdown
# <question, one line>

## Answer
<one paragraph: the answer in plain words. Then: **Recommendation:** <what to do next and why,
or "none: this is the user's call" with the trade-off>.>

## Evidence
- <claim> — <path:line | link> (<date or version when it matters>)
- <claim> — <source>

## Confidence
<high | medium | low>: <why; what was checked and what wasn't>

## Open questions
- <what would change the answer, and how to find out>

<!-- model: <name> · sources checked: <n> · date: YYYY-MM-DD -->
```

Rules: answer first; no claim without a source; "unknown" is a valid answer; recommending an
implementation never authorizes it.
