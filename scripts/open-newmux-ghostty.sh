#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ ! -x "$ROOT/bin/newmux" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

NEWMUX_SOCKET=${NEWMUX_SOCKET:-newmux-dev}
"$ROOT/scripts/start-newmux-fresh.sh" kill-only >/dev/null 2>&1 || true

if [ "$(uname)" = Darwin ] && [ -d /Applications/Ghostty.app ]; then
	exec open -na Ghostty.app --args --config-file="$ROOT/ghostty-config/newmux.config"
elif command -v ghostty >/dev/null 2>&1; then
	GHOSTTY=ghostty
elif [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
	GHOSTTY=/Applications/Ghostty.app/Contents/MacOS/ghostty
else
	echo "ghostty CLI was not found on PATH." >&2
	echo "The macOS app executable was not found either." >&2
	echo "After installing Ghostty, open this profile with:" >&2
	echo "  ghostty --config-file=$ROOT/ghostty-config/newmux.config" >&2
	exit 1
fi

exec "$GHOSTTY" --config-file="$ROOT/ghostty-config/newmux.config"
