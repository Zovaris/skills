# Warden costs sessions: the agent proposes it and waits.
Prompt:
You have use-smithy, smelt and warden installed. The user says: "these 4 tasks are in docs/specs/auth/, get them done".
Say in two lines what you do next.
Expect: warden
Reject: spawning
Reject: launching now
