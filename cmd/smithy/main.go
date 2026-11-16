// Command smithy is the one binary behind the smithy skills: settings, names, task lists,
// warden cards and the zero-token waiter.
package main

import (
	"fmt"
	"os"

	"github.com/Zovaris/skills/internal/cards"
	"github.com/Zovaris/skills/internal/config"
	"github.com/Zovaris/skills/internal/harness"
	"github.com/Zovaris/skills/internal/names"
	"github.com/Zovaris/skills/internal/tasks"
	"github.com/Zovaris/skills/internal/wait"
)

// version is set at build time with -ldflags "-X main.version=<v>".
var version = "dev"

const usage = `smithy %s: the binary behind the smithy skills
  smithy config ...     settings and models (smithy config list)
  smithy harness        "<harness> <adapter>" for this shell
  smithy names ...      branch and worktree names
  smithy tasks ...      the shared task list (smithy tasks board --all)
  smithy status         every task list and batch on this machine
  smithy cards ...      warden status cards
  smithy wait ...       wait without tokens for PRs, runs, branches, issues or a batch
  smithy version
Run any command without arguments for its help.
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, usage, version)
		os.Exit(2)
	}
	config.AutoMigrate()
	args := os.Args[2:]
	code := 0
	switch os.Args[1] {
	case "config":
		code = config.Main(args)
	case "harness":
		h, a := harness.Detect()
		fmt.Println(h, a)
	case "names":
		code = names.Main(args)
	case "tasks":
		code = tasks.Main(args)
	case "status":
		code = tasks.Main([]string{"board", "--all"})
	case "cards":
		code = cards.Main(args)
	case "wait":
		code = wait.Main(args)
	case "version", "--version", "-v":
		fmt.Println(version)
	case "engine-probe":
		fmt.Println("smithy-engine", version)
	default:
		fmt.Fprintf(os.Stderr, usage, version)
		code = 2
	}
	os.Exit(code)
}
