package agents

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/Zovaris/smithy/internal/ghx"
)

const skillsUsage = `Finds installed skills, so a skill or a worker can read another skill's SKILL.md directly.
User-invoked skills can't be called by an agent as a slash command, but any agent in any
harness can read the file.
  smithy skills <name>     absolute path of <name>/SKILL.md; exit 1 when not installed
  smithy skills --list     ` + "`<name> <path>`" + ` for every skill of this repo that is installed`

// Known are the skills of this repo, in the order --list prints them.
var Known = []string{"use-smithy", "smelt", "warden", "ledger", "scout", "tend", "hush", "simple"}

func envOr(getenv func(string) string, key, def string) string {
	if v := getenv(key); v != "" {
		return v
	}
	return def
}

// SkillCandidates lists where a skill's SKILL.md may be, in lookup order: next to the running
// skill (skillDir is its scripts folder), the repo at top, then each harness's user folder.
func SkillCandidates(name, skillDir, top, home string, getenv func(string) string) []string {
	var c []string
	if skillDir != "" {
		c = append(c, filepath.Join(skillDir, "..", "..", name, "SKILL.md"))
	}
	if top != "" {
		c = append(c, filepath.Join(top, ".agents", "skills", name, "SKILL.md"), filepath.Join(top, ".claude", "skills", name, "SKILL.md"))
	}
	for _, d := range []string{
		filepath.Join(home, ".agents", "skills"),
		filepath.Join(home, ".claude", "skills"),
		filepath.Join(home, ".codex", "skills"),
		filepath.Join(envOr(getenv, "XDG_CONFIG_HOME", filepath.Join(home, ".config")), "opencode", "skills"),
		filepath.Join(home, ".gemini", "skills"),
		filepath.Join(home, ".cursor", "skills"),
		filepath.Join(envOr(getenv, "PI_CODING_AGENT_DIR", filepath.Join(home, ".pi", "agent")), "skills"),
		filepath.Join(envOr(getenv, "DSH_HOME", filepath.Join(home, ".dsh")), "skills"),
	} {
		c = append(c, filepath.Join(d, name, "SKILL.md"))
	}
	return c
}

// FindSkill returns the absolute, symlink-free path of an installed skill's SKILL.md.
func FindSkill(name string) (string, bool) {
	cwd, _ := os.Getwd()
	home := os.Getenv("HOME")
	if home == "" {
		home, _ = os.UserHomeDir()
	}
	for _, f := range SkillCandidates(name, ghx.SkillDir(), ghx.RepoRoot(cwd), home, os.Getenv) {
		if !isFile(f) {
			continue
		}
		d, err := filepath.EvalSymlinks(filepath.Dir(f))
		if err != nil {
			continue
		}
		if d, err = filepath.Abs(d); err == nil {
			return filepath.Join(d, "SKILL.md"), true
		}
	}
	return "", false
}

// SkillsMain runs `smithy skills` and returns the exit code.
func SkillsMain(args []string) int {
	a := ""
	if len(args) > 0 {
		a = args[0]
	}
	switch a {
	case "--list":
		for _, s := range Known {
			if p, ok := FindSkill(s); ok {
				fmt.Println(s, p)
			}
		}
		return 0
	case "", "-h", "--help":
		fmt.Println(skillsUsage)
		return 2
	}
	p, ok := FindSkill(a)
	if !ok {
		return 1
	}
	fmt.Println(p)
	return 0
}
