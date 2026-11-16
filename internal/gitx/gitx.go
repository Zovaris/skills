// Package gitx holds the git and pull request commands: commit, pr, cleanup, verify and pr-state.
package gitx

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/Zovaris/skills/internal/ghx"
)

func die(prefix, format string, a ...any) int {
	fmt.Fprintf(os.Stderr, "%s: %s\n", prefix, fmt.Sprintf(format, a...))
	return 1
}

func code(err error) int {
	var ee *exec.ExitError
	if errors.As(err, &ee) && ee.ExitCode() > 0 {
		return ee.ExitCode()
	}
	return 1
}

func attached(name string, args ...string) int {
	cmd := exec.Command(name, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return code(err)
	}
	return 0
}

func quiet(name string, args ...string) error {
	return exec.Command(name, args...).Run()
}

func stderrOnly(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func git(args ...string) string {
	out, _ := ghx.Run("git", args...)
	return out
}

func lines(s string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if l != "" {
			out = append(out, l)
		}
	}
	return out
}
