#!/usr/bin/env bash
# Installs any missing toolchain binary with cargo. Skips tools already on PATH.
set -euo pipefail

install_tool() {
	local bin="$1" crate="$2" version="$3"
	if command -v "$bin" >/dev/null 2>&1; then
		echo "$bin already installed: $("$bin" --version)"
	else
		cargo install "$crate" --version "$version" --locked
	fi
}

install_tool rojo rojo 7.7.1
install_tool lune lune 0.11.1
install_tool stylua stylua 2.6.0
install_tool selene selene 0.31.0

for bin in rojo lune stylua selene; do
	"$bin" --version
done
