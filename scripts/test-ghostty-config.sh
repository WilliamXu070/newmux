#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG="$ROOT/ghostty-config/newmux.config"
CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
PATCHED_GHOSTTY=${NEWMUX_GHOSTTY_BIN:-"$CACHE_HOME/newmux/ghostty-macos-build/Debug/Ghostty.app/Contents/MacOS/ghostty"}

if [ -x "$PATCHED_GHOSTTY" ]; then
	GHOSTTY=$PATCHED_GHOSTTY
elif command -v ghostty >/dev/null 2>&1; then
	GHOSTTY=ghostty
elif [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
	GHOSTTY=/Applications/Ghostty.app/Contents/MacOS/ghostty
else
	echo "Ghostty executable not found; skipping config validation" >&2
	exit 77
fi

"$GHOSTTY" +validate-config --config-file="$CONFIG"
echo "Ghostty config validated: $CONFIG"
