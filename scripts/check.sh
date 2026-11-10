#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

stylua --check src tests
selene src
mkdir -p build && rojo build -o build/IsleOfAvarice.rbxlx
lune run tests/run
