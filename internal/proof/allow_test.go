package proof

import (
	"reflect"
	"testing"
)

func TestAllowedLines(t *testing.T) {
	diff := "diff --git a/a.go b/a.go\n+++ b/a.go\n@@ -1,0 +3,3 @@\n+x := 1\n" +
		"+key := \"AKIAABCDEFGHIJKLMNOP\" // smithy:allow\n" + // smithy:allow (fixture)
		"+y // smithy:allow\n-z // smithy:allow\n"
	got := AllowedLines(diff)
	want := []string{"a.go:4", "a.go:5"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %q want %q", got, want)
	}
	if s := AllowNote(got); s != "scan: skipped 2 lines marked smithy:allow: a.go:4, a.go:5" {
		t.Fatalf("note %q", s)
	}
	if s := AllowNote([]string{"b:1"}); s != "scan: skipped 1 line marked smithy:allow: b:1" {
		t.Fatalf("note %q", s)
	}
}
