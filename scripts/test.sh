#!/usr/bin/env zsh
# Run the SightCore unit tests from this repo's root.
set -euo pipefail

cd "$(dirname "$0")/../SightCore"
swift test --scratch-path "${1:-$PWD/.build}"
