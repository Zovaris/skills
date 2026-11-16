package docs

import (
	"os"
	"path/filepath"
	"testing"
)

func TestADRSlug(t *testing.T) {
	cases := map[string]string{
		"Use Postgres for events": "use-postgres-for-events",
		"  --Hello, World!-- ":    "hello-world",
		"Añadir búsqueda":         "a-adir-b-squeda",
		"!!!":                     "",
	}
	for in, want := range cases {
		if got := ADRSlug(in); got != want {
			t.Errorf("ADRSlug(%q) = %q, want %q", in, got, want)
		}
	}
	if got := ADRSlug("a b c d e f g h i j k l m n o p q r s t u v w x y z a b c d e f"); len(got) != 60 {
		t.Errorf("slug not cut to 60: %d", len(got))
	}
}

func TestNextADRNumber(t *testing.T) {
	dir := t.TempDir()
	if got := NextADRNumber(dir); got != "0001" {
		t.Errorf("empty dir: %s", got)
	}
	for _, n := range []string{"0000-record.md", "0002-b.md", "0010-c.md", "notes.md", "12345-long.md"} {
		if err := os.WriteFile(filepath.Join(dir, n), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if got := NextADRNumber(dir); got != "1235" {
		t.Errorf("got %s, want 1235", got)
	}
	if got := NextADRNumber(filepath.Join(dir, "missing")); got != "0001" {
		t.Errorf("missing dir: %s", got)
	}
}
