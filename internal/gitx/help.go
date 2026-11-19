package gitx

// Usage texts for `smithy <command> --help`, printed by the dispatcher.
var (
	CommitUsage  = commitUsage
	PRUsage      = prUsage
	CleanupUsage = cleanupUsage
	VerifyUsage  = verifyUsage
	PRStateUsage = prStateUsage + "\n       smithy pr-state --from <view.json> <threads.json> <compare.json>"
)
