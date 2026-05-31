#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ ! -x "$ROOT/bin/newmux" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

if [ "$(uname)" = Darwin ] && [ -d /Applications/Ghostty.app ]; then
	exec open -na Ghostty.app --args --config-file="$ROOT/ghostty/scroll-test.config"
elif command -v ghostty >/dev/null 2>&1; then
	exec ghostty --config-file="$ROOT/ghostty/scroll-test.config"
elif [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
	exec /Applications/Ghostty.app/Contents/MacOS/ghostty \
		--config-file="$ROOT/ghostty/scroll-test.config"
else
	echo "ghostty CLI was not found on PATH." >&2
	exit 1
fi
