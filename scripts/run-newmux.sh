#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
CONF="$ROOT/config/newmux-dev.tmux.conf"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-dev}
DEBUG_LOG_DIR=${NEWMUX_DEBUG_LOG_DIR:-}
VERBOSE_FLAGS=

if [ ! -x "$NEWMUX" ]; then
	echo "newmux binary is missing; building it first..." >&2
	"$ROOT/scripts/build-newmux.sh"
fi

if [ -n "$DEBUG_LOG_DIR" ]; then
	mkdir -p "$DEBUG_LOG_DIR"
	VERBOSE_FLAGS=-vv
	cd "$DEBUG_LOG_DIR"
fi

exec "$NEWMUX" $VERBOSE_FLAGS -L "$SOCKET_NAME" -f "$CONF" "$@"
