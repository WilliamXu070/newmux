#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ ! -x "$ROOT/bin/newmux" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
PATCHED_GHOSTTY_APP=${NEWMUX_GHOSTTY_APP:-"$CACHE_HOME/newmux/ghostty-macos-build/Debug/Ghostty.app"}

if [ "$(uname)" = Darwin ] && [ -d "$PATCHED_GHOSTTY_APP" ]; then
	exec open -na "$PATCHED_GHOSTTY_APP" --args --config-file="$ROOT/ghostty-config/scroll-test.config"
elif [ "$(uname)" = Darwin ] && [ -d /Applications/Ghostty.app ]; then
	echo "Using /Applications/Ghostty.app; run scripts/build-ghostty.sh for precise Newmux scroll metadata." >&2
	exec open -na Ghostty.app --args --config-file="$ROOT/ghostty-config/scroll-test.config"
elif command -v ghostty >/dev/null 2>&1; then
	exec ghostty --config-file="$ROOT/ghostty-config/scroll-test.config"
elif [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
	exec /Applications/Ghostty.app/Contents/MacOS/ghostty \
		--config-file="$ROOT/ghostty-config/scroll-test.config"
else
	echo "ghostty CLI was not found on PATH." >&2
	exit 1
fi
