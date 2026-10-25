#!/usr/bin/env zsh
# Run swift-format check on this repo (SightCore + app + tests).
# The vendored Core AI runtime is third-party code and is left untouched.
set -euo pipefail

cd "$(dirname "$0")/.."
files=$(find Sight SightCore SightTests SightUITests -name "*.swift" \
  -not -path "Sight/Vendor/*" \
  -not -path "*/.build/*")
exec swift format lint --strict ${=files}
