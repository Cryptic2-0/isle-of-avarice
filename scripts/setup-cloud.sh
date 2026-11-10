#!/usr/bin/env bash
# Installs any missing toolchain binary with cargo. Skips tools already on PATH.
set -euo pipefail

install_tool() {
	local bin="$1" crate="$2" version="$3"
	shift 3
	if command -v "$bin" >/dev/null 2>&1; then
		echo "$bin already installed: $("$bin" --version)"
	else
		cargo install "$crate" --version "$version" --locked "$@"
	fi
}

install_tool rojo rojo 7.7.1
install_tool lune lune 0.11.1
# StyLua must be built with Luau support. A build without it cannot read type
# annotations and silently skips those files, so reinstall if the probe fails.
if command -v stylua >/dev/null 2>&1 && ! echo 'local x: number = 1' | stylua - >/dev/null 2>&1; then
	echo "stylua has no Luau support, reinstalling"
	cargo install stylua --version 2.6.0 --locked --features luau --force
fi
install_tool stylua stylua 2.6.0 --features luau
install_tool selene selene 0.31.0

for bin in rojo lune stylua selene; do
	"$bin" --version
done
