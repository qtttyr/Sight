#!/usr/bin/env zsh
# Run swift-format check on this repo (SightCore + app + tests).
set -euo pipefail

cd "$(dirname "$0")/.."
exec swift format lint --recursive --strict \
  Sight SightCore SightTests SightUITests
