#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RUN_ROOT="$ROOT/.local/newmux-ghostty/latest"
XDG_HOME="$RUN_ROOT/xdg"

if [ ! -x "$ROOT/bin/newmux" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

rm -rf "$RUN_ROOT"
mkdir -p "$XDG_HOME/ghostty"
: > "$XDG_HOME/ghostty/config"

NEWMUX_SOCKET=${NEWMUX_SOCKET:-newmux-dev}
"$ROOT/scripts/start-newmux-fresh.sh" kill-only >/dev/null 2>&1 || true

CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
PATCHED_GHOSTTY_APP=${NEWMUX_GHOSTTY_APP:-"$CACHE_HOME/newmux/ghostty-macos-build/Debug/Ghostty.app"}
USE_PATCHED_GHOSTTY=${NEWMUX_USE_PATCHED_GHOSTTY:-0}

if [ "$(uname)" = Darwin ] && [ -d "$PATCHED_GHOSTTY_APP" ] && \
	{ [ "$USE_PATCHED_GHOSTTY" = 1 ] || [ -n "${NEWMUX_GHOSTTY_APP:-}" ]; }; then
	exec open -na "$PATCHED_GHOSTTY_APP" \
		--env XDG_CONFIG_HOME="$XDG_HOME" \
		--args --config-file="$ROOT/ghostty-config/newmux.config"
elif [ "$(uname)" = Darwin ] && [ -d /Applications/Ghostty.app ]; then
	exec open -na Ghostty.app \
		--env XDG_CONFIG_HOME="$XDG_HOME" \
		--args --config-file="$ROOT/ghostty-config/newmux.config"
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

exec env XDG_CONFIG_HOME="$XDG_HOME" "$GHOSTTY" \
	--config-file="$ROOT/ghostty-config/newmux.config"
