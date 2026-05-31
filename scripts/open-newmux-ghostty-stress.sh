#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REAL_PROFILE="$ROOT/ghostty-config/newmux.config"
LOG_ROOT="$ROOT/.local/stress-logs/$(date +%Y%m%d-%H%M%S)-real-profile"
TMP_CONFIG="$LOG_ROOT/ghostty-newmux-stress.config"
USER_CONFIG="$HOME/.config/ghostty/config"
BACKUP="$HOME/.config/ghostty/config.newmux-stress-restore"

mkdir -p "$LOG_ROOT" "$HOME/.config/ghostty"

if [ ! -x "$ROOT/bin/newmux" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

cp "$REAL_PROFILE" "$TMP_CONFIG"
perl -0pi -e 's#^input = raw:.*$#input = raw:NEWMUX_DEBUG_LOG_DIR='"$LOG_ROOT"' exec '"$ROOT"'/scripts/start-newmux-fresh.sh\\r#m' "$TMP_CONFIG"

if [ -f "$USER_CONFIG" ]; then
	cp "$USER_CONFIG" "$BACKUP"
else
	: > "$BACKUP"
fi
cp "$TMP_CONFIG" "$USER_CONFIG"

if [ "$(uname)" = Darwin ]; then
	open -na Ghostty.app
else
	ghostty
fi

sleep 3
mv "$BACKUP" "$USER_CONFIG"

echo "Newmux stress Ghostty launched with the real profile."
echo "logs: $LOG_ROOT"
echo "config: $TMP_CONFIG"
