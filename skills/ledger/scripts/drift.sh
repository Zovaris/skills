#!/usr/bin/env bash
# ledger: deterministic doc-drift report against a base (default: merge-base with the default branch).
#   drift.sh [base]
# Sections: changed code and the docs that mention it (by path or exported symbol); paths and
# `name()` symbols named in docs that no longer exist; public API added or changed without any
# doc change in the diff. Report only: always exits 0. Judgement comes after (references/DRIFT.md).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
cd "$(git rev-parse --show-toplevel)"
exec python3 -I "$DIR/drift.py" "$@"
