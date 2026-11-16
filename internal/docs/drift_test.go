package docs

import (
	"strings"
	"testing"
)

func TestExportedName(t *testing.T) {
	cases := map[string]string{
		"export function invoiceTotal(lines) {":   "invoiceTotal",
		"export default async function* gen() {}": "gen",
		"def handler(event):":                     "handler",
		"async def fetch(x):":                     "fetch",
		"class Invoice:":                          "Invoice",
		"func (s *Store) Save() error {":          "Save",
		"func helper() {}":                        "",
		"type Config struct {":                    "Config",
		"pub async fn run() {}":                   "run",
		"public static List<String> names() {":    "names",
		"fun main() {":                            "main",
		"const x = 1":                             "",
	}
	for line, want := range cases {
		if got := ExportedName(line); got != want {
			t.Errorf("ExportedName(%q) = %q, want %q", line, got, want)
		}
	}
}

func TestMentionReasons(t *testing.T) {
	syms := map[string]bool{"invoiceTotal": true, "tax": true}
	got := MentionReasons("src/billing/invoice.ts", syms, "See `src/billing/invoice.ts` and invoiceTotal().")
	want := "invoice, invoice.ts, invoiceTotal, src/billing/invoice.ts"
	if strings.Join(got, ", ") != want {
		t.Errorf("got %q, want %q", got, want)
	}
	if got := MentionReasons("a/b.go", syms, "nothing here"); len(got) != 0 {
		t.Errorf("unexpected reasons %q", got)
	}
}

func TestMissingRefs(t *testing.T) {
	t.Chdir(t.TempDir())
	write(t, "pkg/sub/live.go", "package sub\n")
	calls := 0
	corpus := func() string { calls++; return "function invoiceTotal() {}" }
	text := "See `pkg/sub/live.go`, `sub/live.go`, `src/gone.ts`, `invoiceTotal()`, `removedFn()`, `https://x.io/a.md`, `*.go/x.ts`."
	got := MissingRefs("pkg/README.md", text, corpus)
	want := []string{"pkg/README.md: symbol `removedFn()`", "pkg/README.md: path `src/gone.ts`"}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Errorf("got %q, want %q", got, want)
	}
	if calls == 0 {
		t.Error("corpus never read")
	}
}

func TestAddedAPI(t *testing.T) {
	diff := "diff --git a/x.ts b/x.ts\n--- a/x.ts\n+++ b/x.ts\n@@ -1,0 +2 @@\n+export function invoiceTax(t) {}\n+const local = 1\n-export function old() {}\n"
	got := AddedAPI(diff)
	if len(got) != 1 || got[0] != "x.ts: invoiceTax" {
		t.Errorf("got %q", got)
	}
}
