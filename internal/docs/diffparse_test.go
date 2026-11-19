package docs

import (
	"reflect"
	"testing"
)

const trickyDiff = "diff --git a/x.go b/x.go\n" +
	"--- a/x.go\n" +
	"+++ b/x.go\n" +
	"@@ -0,0 +1,2 @@\n" +
	"+++ not a header\n" +
	"+func Foo() {}\n" +
	"@@ -0,0 +5 @@\n" +
	"+x\n" +
	"diff --git \"a/new\\nline.go\" \"b/new\\nline.go\"\n" +
	"--- /dev/null\n" +
	"+++ \"b/new\\nline.go\"\n" +
	"@@ -0,0 +1 @@\n" +
	"+func Bar() {}\n"

func TestAddedLinesHeaderOnlyAfterDiffGit(t *testing.T) {
	got := AddedLines(trickyDiff)
	want := map[string]map[int]bool{
		"x.go":         {1: true, 2: true, 5: true},
		"new\nline.go": {1: true},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v", got)
	}
}

func TestAddedAPIHeaderOnlyAfterDiffGit(t *testing.T) {
	got := AddedAPI(trickyDiff)
	want := []string{"x.go: Foo", "new\nline.go: Bar"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %q", got)
	}
}
