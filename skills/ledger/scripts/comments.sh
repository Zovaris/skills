#!/usr/bin/env bash
# ledger: checks the comment policy and prints `file:line: reason` per forbidden comment.
#   comments.sh [paths...]         files or folders (default: the repo)
#   comments.sh --diff <base>      only files changed against <base> (and staged ones)
# Allowed: public API doc comments, license/SPDX headers, shebangs, a shell script's header block,
# tool directives with a reason, go:build/generate, Rust /// //! and SAFETY. Everything else is
# reported. Heuristic: languages ts tsx js jsx mjs cjs py go rs java kt sh. Exit 1 on findings.
set -euo pipefail
exec python3 -I "$(cd "$(dirname "$0")" && pwd -P)/comments.py" "$@"
