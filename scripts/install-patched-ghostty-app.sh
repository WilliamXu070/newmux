#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
PATCHED_APP=${NEWMUX_GHOSTTY_APP:-"$CACHE_HOME/newmux/ghostty-macos-build/Debug/Ghostty.app"}
TARGET_APP=${NEWMUX_GHOSTTY_INSTALL_TARGET:-/Applications/Ghostty.app}
BACKUP_DIR="$ROOT/.local/app-backups"

if [ ! -d "$PATCHED_APP" ]; then
	echo "Patched Ghostty app was not found: $PATCHED_APP" >&2
	echo "Build it first with: $ROOT/scripts/build-ghostty.sh" >&2
	exit 1
fi

mkdir -p "$BACKUP_DIR"

if [ -d "$TARGET_APP" ]; then
	STAMP=$(date +%Y%m%d-%H%M%S)
	BACKUP_APP="$BACKUP_DIR/Ghostty.app.$STAMP"
	echo "Backing up $TARGET_APP to $BACKUP_APP"
	ditto "$TARGET_APP" "$BACKUP_APP"
fi

echo "Installing patched Ghostty to $TARGET_APP"
ditto "$PATCHED_APP" "$TARGET_APP"
xattr -cr "$TARGET_APP" 2>/dev/null || true
codesign --force --deep --sign - "$TARGET_APP" >/dev/null

echo "Installed patched Ghostty:"
"$TARGET_APP/Contents/MacOS/ghostty" --version | sed -n '1,8p'
