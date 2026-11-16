package names

import "testing"

func TestBranch(t *testing.T) {
	t.Setenv("SMITHY_CONFIG", t.TempDir()+"/config.json")
	cases := []struct{ key, title, want string }{
		{"PROJ-123", "Add login with Google", "feat/PROJ-123-add-login-with-google"},
		{"#42", "Fix null crash", "fix/42-null-crash"},
		{"-", "Update README", "docs/update-readme"},
		{"03", "Añadir búsqueda", "feat/03-anadir-busqueda"},
	}
	for _, c := range cases {
		if got := Branch(c.key, c.title, ""); got != c.want {
			t.Errorf("Branch(%q, %q) = %q, want %q", c.key, c.title, got, c.want)
		}
	}
}

func TestSlugCap(t *testing.T) {
	if s := Slug("a very long title that keeps going and going past forty chars"); len(s) > 40 || s[len(s)-1] == '-' {
		t.Errorf("Slug too long or ends in a dash: %q", s)
	}
}
