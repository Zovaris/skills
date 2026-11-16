# scout

Answers one question by reading, never by changing anything: "can we…", "what does library Z
do", "how does this code work", "A or B?". Every claim cites its source (`path:line`, docs,
changelogs), and the report recommends; it never authorizes.

Started by the agent when a fact is needed, or by you: `/scout <question> [--out <file>]`.

## How it works

1. Frames the question and splits it into a few sub-questions.
2. Runs a read-only investigator on your **cheap** model (the strong one only when you ask or
   the question is about security, money or data loss).
3. Returns a short report: answer first, then evidence, open questions and a recommendation.

Facts go to scout; decisions go to you.
