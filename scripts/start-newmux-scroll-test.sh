#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_NAME=${NEWMUX_SOCKET:-newmux-scroll-test}

NEWMUX_SOCKET="$SOCKET_NAME" "$ROOT/scripts/start-newmux-fresh.sh" kill-only >/dev/null 2>&1 || true

NEWMUX_SOCKET="$SOCKET_NAME"
export NEWMUX_SOCKET

exec "$ROOT/scripts/run-newmux.sh" new-session -A -s newmux-scroll \
	"$ROOT/scripts/scroll-test-shell.sh"
