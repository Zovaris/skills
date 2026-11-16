// Package docs holds the ledger skill's commands: ADRs, doc search, the comment policy and drift.
package docs

import (
	"os"
	"os/exec"
	"strings"
)

var skipDirs = map[string]bool{
	".git": true, "node_modules": true, "vendor": true, "dist": true, "build": true,
	"target": true, ".venv": true, "__pycache__": true,
}

func wantsHelp(args []string) bool {
	return len(args) > 0 && (args[0] == "-h" || args[0] == "--help")
}

func git(args ...string) string {
	out, _ := exec.Command("git", args...).Output()
	return string(out)
}

func readText(p string) (string, bool) {
	b, err := os.ReadFile(p)
	if err != nil {
		return "", false
	}
	return strings.ToValidUTF8(string(b), "�"), true
}

func readLines(text string) []string {
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")
	if text == "" {
		return nil
	}
	lines := strings.Split(text, "\n")
	if lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	return lines
}

func splitLines(text string) []string {
	var out []string
	r := []rune(text)
	start := 0
	for i := 0; i < len(r); i++ {
		switch r[i] {
		case '\n', '\v', '\f', '\x1c', '\x1d', '\x1e', '\u0085', ' ', ' ':
			out = append(out, string(r[start:i]))
			start = i + 1
		case '\r':
			out = append(out, string(r[start:i]))
			if i+1 < len(r) && r[i+1] == '\n' {
				i++
			}
			start = i + 1
		}
	}
	if start < len(r) {
		out = append(out, string(r[start:]))
	}
	return out
}

func splitExt(p string) (string, string) {
	sep := strings.LastIndexByte(p, '/')
	dot := strings.LastIndexByte(p, '.')
	if dot <= sep {
		return p, ""
	}
	for i := sep + 1; i < dot; i++ {
		if p[i] != '.' {
			return p[:dot], p[dot:]
		}
	}
	return p, ""
}

func joinPath(dir, name string) string {
	if dir == "" || strings.HasPrefix(name, "/") {
		return name
	}
	if strings.HasSuffix(dir, "/") {
		return dir + name
	}
	return dir + "/" + name
}

func walkFiles(root string, skip map[string]bool, visit func(dir, name string)) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return
	}
	var dirs []string
	for _, e := range entries {
		p := joinPath(root, e.Name())
		isDir := e.IsDir()
		if e.Type()&os.ModeSymlink != 0 {
			if st, err := os.Stat(p); err == nil && st.IsDir() {
				continue
			}
		}
		if isDir {
			if !skip[e.Name()] {
				dirs = append(dirs, p)
			}
			continue
		}
		visit(root, e.Name())
	}
	for _, d := range dirs {
		walkFiles(d, skip, visit)
	}
}

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.Mode().IsRegular()
}

func exists(p string) bool {
	if p == "" {
		return false
	}
	_, err := os.Stat(p)
	return err == nil
}
