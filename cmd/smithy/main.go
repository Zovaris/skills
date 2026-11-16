// Command smithy is the one binary behind the smithy skills. Each command group registers
// itself from its own cmd_*.go file, so groups are added without touching this one.
package main

import (
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/Zovaris/skills/internal/config"
)

// version is set at build time with -ldflags "-X main.version=<v>".
var version = "dev"

type command struct {
	help string
	run  func(args []string) int
}

var commands = map[string]command{}

// register adds a top-level command; help is one line for `smithy` with no arguments.
func register(name, help string, run func(args []string) int) {
	commands[name] = command{help, run}
}

func init() {
	register("version", "print the version", func([]string) int { fmt.Println(version); return 0 })
	register("engine-probe", "", func([]string) int { fmt.Println("smithy-engine", version); return 0 })
}

func usage() {
	fmt.Fprintf(os.Stderr, "smithy %s: the binary behind the smithy skills\n", version)
	names := make([]string, 0, len(commands))
	for n, c := range commands {
		if c.help != "" {
			names = append(names, n)
		}
	}
	sort.Strings(names)
	for _, n := range names {
		fmt.Fprintf(os.Stderr, "  smithy %-12s %s\n", n, commands[n].help)
	}
	fmt.Fprintln(os.Stderr, "Run any command without arguments (or with --help) for its usage.")
}

func main() {
	if len(os.Args) < 2 || strings.HasPrefix(os.Args[1], "-") && os.Args[1] != "--version" {
		usage()
		os.Exit(2)
	}
	name := os.Args[1]
	if name == "--version" || name == "-v" {
		name = "version"
	}
	c, ok := commands[name]
	if !ok {
		fmt.Fprintf(os.Stderr, "unknown command %s\n", name)
		usage()
		os.Exit(2)
	}
	config.AutoMigrate()
	os.Exit(c.run(os.Args[2:]))
}
