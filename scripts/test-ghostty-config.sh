#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG="$ROOT/ghostty-config/newmux.config"

if command -v ghostty >/dev/null 2>&1; then
	GHOSTTY=ghostty
elif [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
	GHOSTTY=/Applications/Ghostty.app/Contents/MacOS/ghostty
else
	echo "Ghostty executable not found; skipping config validation" >&2
	exit 77
fi

"$GHOSTTY" +validate-config --config-file="$CONFIG"
echo "Ghostty config validated: $CONFIG"
