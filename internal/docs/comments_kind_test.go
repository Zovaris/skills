package docs

import "testing"

func TestKindProseIsNotCode(t *testing.T) {
	for text, want := range map[string]string{
		"a map because lookups must be O(1)":      "explanatory comment",
		"if the cache is cold, warm it first":     "explanatory comment",
		"for now we skip the retry (see #12)":     "explanatory comment",
		"return early when the list is empty":     "explanatory comment",
		"x = compute()":                           "commented-out code",
		"return a + b;":                           "commented-out code",
		"fetchAll(ctx)":                           "commented-out code",
		"if (x > 1) {":                            "commented-out code",
		"import os":                               "commented-out code",
		"const d = a - b":                         "commented-out code",
		"for i := range xs {":                     "commented-out code",
		"return x":                                "commented-out code",
		"call foo(x) here so the lock is dropped": "explanatory comment",
	} {
		if got := kind(text); got != want {
			t.Errorf("%q: got %q want %q", text, got, want)
		}
	}
}
