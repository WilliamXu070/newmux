#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NEWMUX="$ROOT/bin/newmux"
CONF="$ROOT/config/newmux-dev.tmux.conf"
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-dev}

if [ ! -x "$NEWMUX" ]; then
	echo "newmux binary is missing; building it first..." >&2
	"$ROOT/scripts/build-newmux.sh"
fi

exec "$NEWMUX" -L "$SOCKET_NAME" -f "$CONF" "$@"
