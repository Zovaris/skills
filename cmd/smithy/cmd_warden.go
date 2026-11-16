package main

import "github.com/Zovaris/skills/internal/warden"

func init() {
	register("doctor", "check everything a warden batch needs (--quiet: problems only)", warden.Doctor)
	register("wait-turn", "a launched warden worker waits for its prereqs and a free slot", warden.WaitTurn)
}
