# Models

No model is hard-coded, and workers don't simply inherit yours. `smithy config get
warden.worker_model` decides:

- `route` (default): `smithy route --file <task file or intent> --kind <ship|scout> --speed <speed>`
  per item; launch it on the model of the tier it picks (cheap: small or read-only, mid: most
  features, strong: risky, hard or large). Look at each pick and move it one tier when you know
  better, saying why.
- `session`: every worker on the parent session's model.
- Any other value: that model for every worker.

A `model` the user named, for the batch or one item, always wins. The plan line shows each item's
tier and model; `batch.json` stores it as `model`.

Unset tiers print `-`: in the plan line propose `smithy config suggest-models` ("cheap haiku, mid
sonnet, strong opus, ok?") and on a yes run `smithy config accept-models`; with no suggestions ask for
each tier (`smithy config set-model <tier> <name>`). Until then that item uses the session default.

Other roles: `smithy consult` uses `strong`; tend runs on `cheap` and hands code fixes to `strong`.
