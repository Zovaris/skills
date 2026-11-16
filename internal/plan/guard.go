package plan

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"

	"github.com/Zovaris/skills/internal/ghx"
)

const guardUsage = `smelt: blocks edits to test files during the green phase of TDD.
Active only while ` + "`.smelt/green`" + ` exists in the project root; otherwise it allows everything.

  smithy guard-tests <file-path>      generic: exit 2 + message if the path is a protected test file
  smithy guard-tests < hook.json      hook mode: reads {"cwd", "tool_input": {"file_path"}} on stdin

Wire it as a pre-edit hook in any harness that has one (optional; smelt works without it):
  Claude Code (.claude/settings.json):
    "hooks": { "PreToolUse": [ { "matcher": "Edit|Write|MultiEdit",
      "hooks": [ { "type": "command", "command": "<skill-dir>/scripts/smithy guard-tests" } ] } ] }
  Other harnesses: call ` + "`smithy guard-tests \"<file being edited>\"`" + ` from their pre-edit hook/plugin
  and refuse the edit on exit 2.
Add ` + "`.smelt/`" + ` to .gitignore.`

// GreenMessage is what guard-tests prints when it refuses an edit.
const GreenMessage = "smelt: green phase — tests are read-only. If this test contradicts the spec, stop and say so; remove .smelt/green to start the next red step."

var testPath = regexp.MustCompile(`(^|/)(tests?|__tests__|spec|e2e)/|\.(test|spec|adversary|property)\.[a-z]+$|(^|/)test_[^/]*\.py$|_test\.(go|py)$|__snapshots__/`)

// IsTestFile reports whether path is a test file the green phase protects.
func IsTestFile(path string) bool { return testPath.MatchString(path) }

// Green reports whether the project holding root is in the green phase (.smelt/green exists).
func Green(root string) bool {
	top := ghx.RepoRoot(root)
	if top == "" {
		top = root
	}
	st, err := os.Stat(filepath.Join(top, ".smelt", "green"))
	return err == nil && st.Mode().IsRegular()
}

// Guard decides an edit: 2 with the message on stderr when it touches a protected test file
// in the green phase, else 0. With no args it reads a pre-edit hook's JSON from stdin.
func Guard(args []string, stdin io.Reader, stderr io.Writer) int {
	var path, root string
	if len(args) >= 1 {
		path = args[0]
	} else {
		var in struct {
			Cwd       any `json:"cwd"`
			ToolInput struct {
				FilePath any `json:"file_path"`
			} `json:"tool_input"`
		}
		b, _ := io.ReadAll(stdin)
		_ = json.Unmarshal(b, &in)
		root, path = text(in.Cwd), text(in.ToolInput.FilePath)
	}
	if root == "" {
		root = os.Getenv("PWD")
		if root == "" {
			root, _ = os.Getwd()
		}
	}
	if !Green(root) {
		return 0
	}
	if IsTestFile(path) {
		fmt.Fprintln(stderr, GreenMessage)
		return 2
	}
	return 0
}

func text(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case bool:
		if !t {
			return ""
		}
		return "true"
	case string:
		return t
	default:
		b, _ := json.Marshal(t)
		return string(b)
	}
}

// GuardMain runs `smithy guard-tests` and returns the exit code.
func GuardMain(args []string) int {
	if len(args) == 1 && (args[0] == "-h" || args[0] == "--help") {
		fmt.Fprintln(os.Stderr, guardUsage)
		return 0
	}
	return Guard(args, os.Stdin, os.Stderr)
}
