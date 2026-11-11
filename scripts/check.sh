#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Fail early if StyLua cannot read Luau type syntax. Without Luau support it
# skips unreadable files in directory mode and still reports success.
if ! echo 'local x: number = 1' | stylua - >/dev/null 2>&1; then
	echo "error: stylua was built without Luau support. Run scripts/setup-cloud.sh." >&2
	exit 1
fi
# Pass each file by name so a parse error fails the check (exit code 2).
find src tests playtest -name '*.luau' -not -path 'src/server/Vendor/*' -print0 | xargs -0 stylua --check
selene src playtest
mkdir -p build && rojo build -o build/IsleOfAvarice.rbxlx
lune run tests/run
