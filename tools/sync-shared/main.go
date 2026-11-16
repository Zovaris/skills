// Command sync-shared copies shared/ (the smithy launcher and VERSION) into every skill that runs
// smithy, so each skill installs on its own. With --check it exits 1 when a copy differs (CI).
//
//	go run ./tools/sync-shared [--check]
package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
)

var skills = []string{"smelt", "warden", "use-smithy", "scout", "tend", "ledger"}
var files = []string{"smithy", "smithy.cmd", "VERSION"}

func main() {
	check := len(os.Args) > 1 && os.Args[1] == "--check"
	bad := false
	for _, s := range skills {
		for _, f := range files {
			src, err := os.ReadFile(filepath.Join("shared", f))
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(2)
			}
			dst := filepath.Join("skills", s, "scripts", f)
			if check {
				if cur, err := os.ReadFile(dst); err != nil || !bytes.Equal(cur, src) {
					fmt.Println("out of sync:", dst)
					bad = true
				}
				continue
			}
			mode := os.FileMode(0o644)
			if f != "VERSION" {
				mode = 0o755
			}
			if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			if err := os.WriteFile(dst, src, mode); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			_ = os.Chmod(dst, mode)
		}
	}
	if check {
		if bad {
			os.Exit(1)
		}
		fmt.Println("shared files in sync")
		return
	}
	fmt.Println("synced shared/ into skills")
}
