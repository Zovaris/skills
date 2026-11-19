# Acting on cards

One section per stage. Every final item goes through `smithy cleanup <repo> <branch> <worktree>`:
worktree and local branch removed, unpushed work refused with `kept <branch>: …`, which goes in the
final message instead of being forced. With `cleanup ask`, list what you would clean and end, and
do it on the user's yes.

## decide (`needs_decision`)

By `impact` (you may raise it, never lower it):
- **low** (local, cheap to undo, restores or completes the intent): decide on the merits.
- **medium** (shapes a module or internal contract): `smithy consult` with the worker's question and
  options verbatim, in neutral order. `NEED-INFO` goes back to the worker; `ESCALATE` makes it
  high.
- **high** (widens scope beyond the intent, customer-visible, money, data, security, public API or
  schema, production, irreversible, or the same kind of finding recurring): the user decides. One
  message with all of them; each gives the intent, the proposed change, the smallest alternative
  that still meets the intent, and your recommendation. Wait.

Relay answers with **tell**, quoting the user's words when they decided, and close the question
yourself: `smithy cards set <batch> <id> state=working decision_key=`. Log low and medium ones in
`decisions.md`.

## verify (`pr_open`, `ready`)

`smithy verify <repo> <branch> <pr-url>` prints one verdict:
- `green`: merge auto and not into production → merge if the worker hasn't (card
  `note=merge-blocked` means it was refused: `gh pr merge` yourself; refused again → list it with
  the doctor's permission hint). Production without the user's yes, or merge manual → card
  `state=ready`, listed for the user.
- `pending`: wait (`smithy wait pr:<pr-url>`).
- `draft`: green but still a draft; list it for the user, never merge it.
- `unpushed` or `red`: back to the worker in one line.
- `merged`: next section.
- `closed` (closed without merge): `state=dropped note="PR closed without merge"`, `smithy cleanup`,
  **end** the worker, set the source to `dropped`, name it in the final message.
- `no-pr`: the worker said `pr_open` without a PR; back to the worker.

## merged

After `smithy verify` says `merged`: `smithy cleanup`, **end** the worker, update the source. Its
dependents are already waiting and start on their own. A `followup: <file>` in the note is work
found after the merge: small and inside the intent → add it as an item (spawn it if this harness
can from here, else propose it); bigger → a scope question for the user, with the other decisions.

## reported · dropped

`reported`: read the report's first lines, **end** the worker, `smithy cleanup`. `dropped`:
`smithy cleanup`, **end** the worker.

## stuck (`blocked`, `failed`, or no card update for 45 min)

Recovery ladder, one rung per wake:
1. Answer from the intent if the note asks something it settles.
2. One corrective line to the worker (**tell**).
3. Relaunch in the **same worktree** with the brief's relaunch line.
4. After a second relaunch fails, tell the user with the `note`.

Never a fresh worktree for the same task.
