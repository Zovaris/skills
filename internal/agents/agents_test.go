package agents

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func env(m map[string]string) func(string) string { return func(k string) string { return m[k] } }

func TestBuild(t *testing.T) {
	none := env(nil)
	cases := []struct {
		cli   string
		o     Options
		extra []string
		git   string
		want  []string
		stdin bool
		h     string
	}{
		{"claude", Options{Model: "opus"}, []string{"--x"}, "", []string{"claude", "-p", "--permission-mode", "auto", "--model", "opus", "--x"}, true, "claude-cli"},
		{"claude", Options{ReadOnly: true}, nil, "", []string{"claude", "-p", "--permission-mode", "plan"}, true, "claude-cli"},
		{"codex", Options{}, nil, "/r/.git", []string{"codex", "exec", "--sandbox", "workspace-write", "-c", "sandbox_workspace_write.network_access=true", "--add-dir", "/r/.git", "-"}, true, "codex"},
		{"codex", Options{ReadOnly: true, Model: "m"}, nil, "", []string{"codex", "exec", "--sandbox", "read-only", "-m", "m", "-"}, true, "codex"},
		{"opencode", Options{}, nil, "", []string{"opencode", "run", "--standalone", "--archived", "--auto", "P"}, false, "opencode"},
		{"opencode", Options{ReadOnly: true, Model: "a/b"}, nil, "", []string{"opencode", "run", "--standalone", "--archived", "--agent", "plan", "-m", "a/b", "P"}, false, "opencode"},
		{"gemini", Options{ReadOnly: true}, nil, "", []string{"gemini", "--approval-mode", "plan", "-p", "P"}, false, "gemini"},
		{"cursor", Options{Model: "m"}, nil, "", []string{"agent", "-p", "--force", "--model", "m", "P"}, false, "cursor"},
		{"pi", Options{ReadOnly: true}, nil, "", []string{"pi", "-p", "--tools", "read", "P"}, false, "pi"},
		{"dsh", Options{ReadOnly: true, Model: "ignored"}, nil, "", []string{"dsh", "headless", "--approval-policy", "never", "--permission-mode", "read-only", "-"}, true, "dsh"},
	}
	for _, c := range cases {
		s, err := Build(c.cli, c.o, "P", c.extra, c.git, none)
		if err != nil || !reflect.DeepEqual(s.Argv, c.want) || s.PromptStdin != c.stdin || s.Harness != c.h {
			t.Errorf("Build(%s, %+v) = %+v, %v; want %q stdin=%v %s", c.cli, c.o, s, err, c.want, c.stdin, c.h)
		}
	}
	s, _ := Build("claude", Options{}, "", nil, "", env(map[string]string{"AGENT_PERMISSION_MODE": "acceptEdits"}))
	if s.Argv[3] != "acceptEdits" {
		t.Errorf("AGENT_PERMISSION_MODE ignored: %q", s.Argv)
	}
	s, _ = Build("custom", Options{}, "", nil, "", env(map[string]string{"AGENT_CMD": "cat", "WARDEN_HARNESS": "pi"}))
	if !reflect.DeepEqual(s, Spec{[]string{"bash", "-c", "cat"}, true, "pi"}) {
		t.Errorf("custom = %+v", s)
	}
	if _, err := Build("", Options{}, "", nil, "", none); err != ErrNoCLI {
		t.Errorf("no CLI: %v", err)
	}
}

func TestResolveCLI(t *testing.T) {
	only := func(bins ...string) func(string) bool {
		return func(b string) bool {
			for _, x := range bins {
				if x == b {
					return true
				}
			}
			return false
		}
	}
	if c := ResolveCLI(env(nil), only("agent", "pi")); c != "cursor" {
		t.Errorf("first installed = %q", c)
	}
	if c := ResolveCLI(env(map[string]string{"AGENT_CLI": "gemini"}), only()); c != "gemini" {
		t.Errorf("AGENT_CLI = %q", c)
	}
	if c := ResolveCLI(env(map[string]string{"AGENT_CLI": "gemini", "AGENT_CMD": "x"}), only()); c != "custom" {
		t.Errorf("AGENT_CMD = %q", c)
	}
}

func TestEnv(t *testing.T) {
	got := Env([]string{"CLAUDECODE=1", "AI_AGENT=x", "PATH=/bin", "WARDEN_HARNESS=old"}, Spec{Harness: "pi"}, Options{PromptFile: "/p", ReadOnly: true})
	want := []string{"PATH=/bin", "AGENT_PROMPT_FILE=/p", "AGENT_MODEL=", "AGENT_READONLY=1", "WARDEN_HARNESS=pi"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("Env = %q", got)
	}
}

func TestSplitArgs(t *testing.T) {
	got := SplitArgs(`--a 'b c' "d \"e\"" f\ g  `)
	want := []string{"--a", "b c", `d "e"`, "f g"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("SplitArgs = %q", got)
	}
}

func TestRoute(t *testing.T) {
	cases := []struct{ text, kind, speed, want string }{
		{"fix typo in README", "ship", "normal", "cheap"},
		{"add OAuth login with tokens", "ship", "normal", "strong"},
		{"add CSV export to reports", "ship", "normal", "mid"},
		{"add CSV export", "ship", "full", "strong"},
		{"", "review", "normal", "cheap"},
		{"refactor the parser", "ship", "normal", "strong"},
		{"refactor the parser", "ship", "fast", "mid"},
		{"fix typo", "fix", "normal", "mid"},
		{"add a page\n## Files\n- a.go\n- b.go\n- c.go\n- d.go\n- e.go\n- f.go\n- g.go\n- h.go\n- i.go\n", "ship", "normal", "strong"},
		{"x\n- [ ] 1\n- [ ] 2\n- [x] 3\n- [ ] 4\n- [ ] 5\n- [ ] 6\n- [ ] 7\n", "ship", "normal", "strong"},
	}
	for _, c := range cases {
		if got, r := Route(c.text, c.kind, c.speed); got != c.want {
			t.Errorf("Route(%q, %s, %s) = %s %q, want %s", c.text, c.kind, c.speed, got, r, c.want)
		}
	}
	if _, r := Route("add CSV export", "ship", "normal"); !reflect.DeepEqual(r, []string{"ordinary feature work"}) {
		t.Errorf("reasons = %q", r)
	}
}

func TestConsultCLI(t *testing.T) {
	have := func(b string) bool { return b == "codex" || b == "agent" }
	for h, want := range map[string]string{"claude-cli": "codex", "cursor": "cursor", "pi": "codex", "unknown": "codex"} {
		if got := ConsultCLI(h, have); got != want {
			t.Errorf("ConsultCLI(%s) = %q, want %q", h, got, want)
		}
	}
	if got := ConsultCLI("pi", func(string) bool { return false }); got != "" {
		t.Errorf("nothing installed = %q", got)
	}
}

func TestConsultPrompt(t *testing.T) {
	p := ConsultPrompt("Q1", "A; B", "ctx-line")
	if !strings.Contains(p, "Question: Q1\nOptions (neutral order): A; B\nContext:\nctx-line\nPick one") || !strings.HasSuffix(p, "Do not use tools.\n") {
		t.Errorf("prompt = %q", p)
	}
	if strings.Contains(ConsultPrompt("q", "o", ""), "Context:") {
		t.Error("empty context printed")
	}
}

func TestSkills(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("SMITHY_SKILL_DIR", "")
	t.Setenv("PI_CODING_AGENT_DIR", filepath.Join(home, "pi"))
	t.Chdir(home)
	dir := filepath.Join(home, "pi", "skills", "scout")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(dir, "SKILL.md"), nil, 0o644)
	os.MkdirAll(filepath.Join(home, ".claude", "skills"), 0o755)
	os.Symlink(dir, filepath.Join(home, ".claude", "skills", "scout"))
	real, _ := filepath.EvalSymlinks(dir)
	if p, ok := FindSkill("scout"); !ok || p != filepath.Join(real, "SKILL.md") {
		t.Errorf("FindSkill(scout) = %q %v", p, ok)
	}
	if _, ok := FindSkill("tend"); ok {
		t.Error("tend found")
	}
	c := SkillCandidates("x", "/s/use-smithy/scripts", "/top", "/h", env(nil))
	if c[0] != "/s/x/SKILL.md" || c[1] != "/top/.agents/skills/x/SKILL.md" || c[len(c)-1] != "/h/.dsh/skills/x/SKILL.md" {
		t.Errorf("candidates = %q", c)
	}
}

func TestBlock(t *testing.T) {
	blk := "<!-- use-smithy:start -->\nhi\n<!-- use-smithy:end -->\n"
	once := AddBlock("# Rules\n", blk)
	if twice := AddBlock(once, blk); twice != once || strings.Count(twice, "use-smithy:start") != 1 {
		t.Errorf("add not idempotent: %q", twice)
	}
	if once != "# Rules\n\n"+blk {
		t.Errorf("add = %q", once)
	}
	if got := StripBlock(once); got != "# Rules\n" || HasBlock(got) {
		t.Errorf("strip = %q", got)
	}
	if AddBlock("", blk) != blk {
		t.Error("add to empty file")
	}
	if f := DefaultFile("codex", "/h", "/w", env(map[string]string{"CODEX_HOME": "/c"})); f != "/c/AGENTS.md" {
		t.Errorf("codex file = %s", f)
	}
	if f := DefaultFile("cursor", "/h", "/w", env(nil)); f != "/w/AGENTS.md" {
		t.Errorf("cursor file = %s", f)
	}
}
