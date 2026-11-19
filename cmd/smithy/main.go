// Command smithy is the one binary behind the smithy skills. Each command group registers
// itself from its own cmd_*.go file, so groups are added without touching this one.
package main

import (
	"fmt"
	"io"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/Zovaris/smithy/internal/config"
)

// version is set at build time with -ldflags "-X main.version=<v>".
var version = "dev"

type command struct {
	help  string
	usage string
	flags map[string]bool
	run   func(args []string) int
}

var commands = map[string]command{}

// register adds a top-level command. help is one line for `smithy --help`; usage is what
// `smithy <name> --help` prints; flags lists the options the command accepts, a trailing
// "=" marking one that takes a value. A bare "--" in flags means the command reads `--` itself;
// for every other command entry drops the first `--` so only clean positionals reach it.
func register(name, help, usage, flags string, run func(args []string) int) {
	f := map[string]bool{}
	for _, x := range strings.Fields(flags) {
		f[strings.TrimSuffix(x, "=")] = strings.HasSuffix(x, "=") || x == "--"
	}
	commands[name] = command{help, usage, f, run}
}

func init() {
	register("version", "print the version", "usage: smithy version\nPrints the version (also smithy --version).", "",
		func([]string) int { fmt.Println(version); return 0 })
	register("engine-probe", "", "usage: smithy engine-probe\nPrints smithy-engine and the version.", "",
		func([]string) int { fmt.Println("smithy-engine", version); return 0 })
}

// entry applies the convention every command shares, before anything runs: -h/--help anywhere
// (up to a bare --) prints the usage on stdout, exit 0; an unknown option exits 2. It returns
// the args the command runs with.
func entry(name string, c command, args []string) ([]string, int, bool) {
	for _, a := range args {
		if a == "--" {
			break
		}
		if a == "-h" || a == "--help" {
			fmt.Println(c.usage)
			return nil, 0, true
		}
	}
	var out []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == "--" {
			if c.flags["--"] {
				out = append(out, a)
			}
			return append(out, args[i+1:]...), 0, false
		}
		out = append(out, a)
		if len(a) < 2 || a[0] != '-' || isNumber(a) {
			continue
		}
		takesValue, ok := c.flags[a]
		if !ok {
			fmt.Fprintf(os.Stderr, "smithy %s: unknown option %s\n", name, a)
			fmt.Fprintln(os.Stderr, c.usage)
			return nil, 2, true
		}
		if takesValue && i+1 < len(args) {
			i++
			out = append(out, args[i])
		}
	}
	return out, 0, false
}

func isNumber(s string) bool {
	_, err := strconv.ParseFloat(s, 64)
	return err == nil
}

func usage(w io.Writer) {
	fmt.Fprintf(w, "smithy %s: the binary behind the smithy skills\n", version)
	names := make([]string, 0, len(commands))
	for n, c := range commands {
		if c.help != "" {
			names = append(names, n)
		}
	}
	sort.Strings(names)
	for _, n := range names {
		fmt.Fprintf(w, "  smithy %-12s %s\n", n, commands[n].help)
	}
	fmt.Fprintln(w, "Run any command with --help for its usage. Not on PATH? smithy setup path.")
}

func main() {
	if len(os.Args) < 2 {
		usage(os.Stderr)
		os.Exit(2)
	}
	switch os.Args[1] {
	case "help", "--help", "-h":
		usage(os.Stdout)
		os.Exit(0)
	}
	name := os.Args[1]
	if name == "--version" || name == "-v" {
		name = "version"
	}
	c, ok := commands[name]
	if !ok {
		fmt.Fprintf(os.Stderr, "unknown command %s\n", name)
		usage(os.Stderr)
		os.Exit(2)
	}
	args, code, done := entry(name, c, os.Args[2:])
	if done {
		os.Exit(code)
	}
	config.AutoMigrate()
	os.Exit(c.run(args))
}
