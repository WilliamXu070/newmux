#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-dev}

if [ ! -x "$ROOT/bin/newmux" ]; then
	"$ROOT/scripts/build-newmux.sh"
fi

PIDS=$(ps ax -o pid=,command= | awk \
	-v bin="$ROOT/bin/newmux" \
	-v socket="$SOCKET_NAME" \
	'{ pid = $1; cmd = $0; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", cmd); if (index(cmd, bin " ") == 1 && index(cmd, " -L " socket) != 0) print pid }')
if [ -n "$PIDS" ]; then
	kill $PIDS >/dev/null 2>&1 || true
	sleep 0.2
	PIDS=$(ps ax -o pid=,command= | awk \
		-v bin="$ROOT/bin/newmux" \
		-v socket="$SOCKET_NAME" \
		'{ pid = $1; cmd = $0; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", cmd); if (index(cmd, bin " ") == 1 && index(cmd, " -L " socket) != 0) print pid }')
	if [ -n "$PIDS" ]; then
		kill -9 $PIDS >/dev/null 2>&1 || true
	fi
fi

rm -f "/tmp/tmux-$(id -u)/$SOCKET_NAME"

if [ "${1:-}" = kill-only ]; then
	exit 0
fi

exec "$ROOT/scripts/run-newmux.sh" new-session -A -s newmux
