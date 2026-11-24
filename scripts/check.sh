#!/usr/bin/env bash
# The four checks. All must pass before code goes into Studio or a PR.
# Run from the repo root: ./scripts/check.sh
set -euo pipefail

echo "1/4 Rojo build"
mkdir -p build
rojo build default.project.json -o build/plantagonist.rbxl

echo "2/4 Unit tests (Lune)"
lune run tests

echo "3/4 Lint (Selene)"
selene src
selene --config tests/selene.toml tests sim

echo "4/4 Format (StyLua)"
stylua --check src tests sim

echo "All four checks passed."
