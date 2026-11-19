# Contributing

- The binary's source is in `cmd/smithy` and `internal/` (Go, standard library only). Inside a
  checkout the launcher builds it from source when a `.go` file changed, so symlinked skills
  always run your working copy.
- Pull requests run `check` (gofmt, vet, `go test`, every offline test through the binary, a
  build per release target). A `v*` tag runs `release`: it checks the tag matches
  `shared/VERSION`, builds darwin, linux (arm64, amd64) and windows binaries, gzips them,
  writes `checksums.txt`, attests the build and publishes the GitHub release with the
  CHANGELOG section as notes.
- `shared/` holds the launcher (`smithy`, `smithy.cmd`) and `VERSION`; edit them there and run
  `go run ./tools/sync-shared`, which copies them into each skill (each skill installs on its own).
- `tests/run.sh` runs every offline test (`go test`, skill lint via `tests/skills.sh`, and the
  `tests/shared`, ledger, warden, scout and tend scripts); CI runs it.
- `scripts/drill.sh` pressure-tests skills against a real agent CLI (`tests/drill/*.md`); it
  costs tokens, so run it by hand per harness.

Commits are atomic and conventional (`smithy commit style` shows the rules); every change lands under
**Unreleased** in [CHANGELOG.md](CHANGELOG.md) first.
